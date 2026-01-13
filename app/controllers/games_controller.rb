class GamesController < ApplicationController
  # Routes of movement
  WHITE_PATH = [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12]
  BLACK_PATH = [23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]

  before_action :set_game, only: %i[ show roll_dice move reset ]
  skip_before_action :verify_authenticity_token, only: [:move]

  def roll_dice
    if @game.available_moves.blank?
      d1, d2 = rand(1..6), rand(1..6)
      moves = (d1 == d2) ? [d1, d1, d1, d1] : [d1, d2]
      @game.update(dice_1: d1, dice_2: d2, available_moves: moves, head_used: false)
      check_for_blocked_turn
    end
    render_game_update
  end

  def move
    from = params[:from_index].to_i
    to = params[:to_index].to_i
    current_color = @game.current_turn == 0 ? 'white' : 'black'
    head_index = (current_color == 'white' ? 11 : 23)

    is_bearing_off = (to < 0)
    if is_bearing_off
      unless all_checkers_in_home?(current_color)
        return render json: { error: 'Bring all the checkers into the house!' }, status: :forbidden
      end
      distance = (current_color == 'white' ? (from - 11) : (from + 1))
    else
      distance = (from - to) % 24
    end

    moves = Array(@game.available_moves)
    move_index = is_bearing_off ? find_bearing_off_dice(moves, distance, from, current_color) : moves.index(distance)

    if move_index.nil?
      return render json: { error: "There is no dice value on #{distance}" }, status: :unprocessable_entity
    end

    new_board = JSON.parse(@game.board_state.to_json)
    source = new_board[from]
    target = is_bearing_off ? nil : new_board[to]

    if source["color"] != current_color
      return render json: { error: "Wrong move of the opponent's checker!" }, status: :forbidden
    end

    # Checking the head rule
    if from == head_index
      count_in_head = source["count"].to_i
      is_double = (@game.dice_1 == @game.dice_2)
      # Exception
      is_first_turn_exception = is_double && (count_in_head == 14)
      if @game.head_used && !is_first_turn_exception
        return render json: { error: 'You can only take one checker from your head!' }, status: :forbidden
      end
    end

    # Checking if a cell is occupied by an opponent
    if target && target["count"] > 0 && target["color"] != current_color
      return render json: { error: 'The point is occupied by an opponent' }, status: :forbidden
    end

    source["count"] -= 1
    source["color"] = nil if source["count"] == 0
    unless is_bearing_off
      target["count"] += 1
      target["color"] = current_color
    end

    # We check the block of 6 checkers on the updated board
    if creates_illegal_prime?(new_board, current_color)
      return render json: { error: 'You cannot build a block of 6 checkers if your opponent has not yet passed it!' }, status: :forbidden
    end

    # Saving the real state
    moves.delete_at(move_index)
    @game.head_used = true if from == head_index
    @game.board_state = new_board
    @game.available_moves = moves

    if is_bearing_off
      current_color == 'white' ? @game.white_borne_off += 1 : @game.black_borne_off += 1
      @game.status = 2 if @game.white_borne_off == 15 || @game.black_borne_off == 15
    end

    @game.current_turn = (@game.current_turn + 1) % 2 if moves.empty?

    if @game.save
      check_for_blocked_turn
      render_game_update
    else
      render json: { error: 'Database error' }, status: :internal_server_error
    end
  end

  def reset
    @game.setup_initial_board
    @game.available_moves = []
    @game.dice_1 = 0; @game.dice_2 = 0
    @game.white_borne_off = 0; @game.black_borne_off = 0
    @game.save
    render_game_update
  end

  private

  def any_legal_moves?
    current_color = @game.current_turn == 0 ? 'white' : 'black'
    path = (current_color == 'white' ? WHITE_PATH : BLACK_PATH)
    head_index = (current_color == 'white' ? 11 : 23)
    available_moves = Array(@game.available_moves).uniq

    @game.board_state.each_with_index do |point, from_idx|
      next unless point["color"] == current_color && point["count"].to_i > 0

      available_moves.each do |dist|
        current_pos = path.index(from_idx)
        target_pos = current_pos + dist

        if target_pos >= 24
          if all_checkers_in_home?(current_color) && find_bearing_off_dice(@game.available_moves, dist, from_idx, current_color)
            return true
          end
          next
        end

        to_idx = path[target_pos]
        target = @game.board_state[to_idx]

        next if target["count"] > 0 && target["color"] != current_color

        if from_idx == head_index
          is_double = (@game.dice_1 == @game.dice_2)
          is_start_exception = is_double && point["count"].to_i == 14
          next if @game.head_used && !is_start_exception
        end

        # Checking the block in simulation
        temp_board = JSON.parse(@game.board_state.to_json)
        temp_board[from_idx]["count"] -= 1
        temp_board[to_idx]["count"] += 1
        temp_board[to_idx]["color"] = current_color
        next if creates_illegal_prime?(temp_board, current_color)

        return true
      end
    end
    false
  end

  def check_for_blocked_turn
    if @game.available_moves.present? && !any_legal_moves?
      @game.update(available_moves: [], current_turn: (@game.current_turn + 1) % 2)
      flash.now[:alert] = "No possible moves! Pass move."
    end
  end

  # RULE OF 6 CHECKS: Check if the opponent is locked in
  def creates_illegal_prime?(board, color)
    my_path = (color == 'white' ? WHITE_PATH : BLACK_PATH)
    opp_path = (color == 'white' ? BLACK_PATH : WHITE_PATH)
    opp_color = (color == 'white' ? 'black' : 'white')

    consecutive = 0
    my_path.each_with_index do |idx, p_idx|
      if board[idx]["color"] == color && board[idx]["count"].to_i > 0
        consecutive += 1
        if consecutive >= 6
          opp_idx_of_fence_end = opp_path.index(idx)
          remaining_opp_path = opp_path[(opp_idx_of_fence_end + 1)..-1] || []

          has_passed = remaining_opp_path.any? { |oidx| board[oidx]["color"] == opp_color }
          return true unless has_passed
        end
      else
        consecutive = 0
      end
    end
    false
  end

  def all_checkers_in_home?(color)
    home_range = (color == 'white') ? (12..17) : (0..5)
    @game.board_state.each_with_index.all? { |p, i| p["count"] == 0 || p["color"] != color || home_range.include?(i) }
  end

  def find_bearing_off_dice(moves, dist, from, color)
    # If there is an exact value of the cube, we use it.
    return moves.index(dist) if moves.index(dist)

    # If there is no exact value of the cube, we look for the value of the larger distance
    bigger_idx = moves.index { |m| m > dist }
    if bigger_idx

      limit = (color == 'white' ? 17 : 5)
      back_range = ((from + 1)..limit)

      has_checkers_behind = @game.board_state.each_with_index.any? do |p, idx|
        back_range.include?(idx) && p["color"] == color && p["count"].to_i > 0
      end

      return bigger_idx unless has_checkers_behind
    end
    nil
  end

  def set_game; @game = Game.find(params[:id]); end

  def render_game_update
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [
        turbo_stream.replace("game_area", partial: "board/game_board", locals: { game: @game }),
        turbo_stream.replace("flash-message", partial: "board/flash_message")
      ]}
      format.json { render json: { status: 'ok' } }
      format.html { redirect_to root_path }
    end
  end
end