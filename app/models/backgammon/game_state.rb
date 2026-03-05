module Backgammon
  class GameState
    attr_reader :board, :available_moves, :dice_1, :dice_2, :current_turn,
                :head_used, :white_borne_off, :black_borne_off, :status, :flash_alert

    def self.from_record(game)
      new(
        board: Backgammon::Board.from_json(game.board_state),
        available_moves: Array(game.available_moves),
        dice_1: game.dice_1.to_i,
        dice_2: game.dice_2.to_i,
        current_turn: game.current_turn.to_i,
        head_used: !!game.head_used,
        white_borne_off: game.white_borne_off.to_i,
        black_borne_off: game.black_borne_off.to_i,
        status: game.status.to_i
      )
    end

    def initialize(board:, available_moves:, dice_1:, dice_2:, current_turn:, head_used:, white_borne_off:, black_borne_off:, status:)
      @board = board
      @available_moves = available_moves
      @dice_1 = dice_1
      @dice_2 = dice_2
      @current_turn = current_turn
      @head_used = head_used
      @white_borne_off = white_borne_off
      @black_borne_off = black_borne_off
      @status = status
      @flash_alert = nil
    end

    def current_color
      current_turn == 0 ? "white" : "black"
    end

    def roll_dice!
      return self if available_moves.any?

      d1 = rand(1..6)
      d2 = rand(1..6)
      moves = (d1 == d2) ? [d1, d1, d1, d1] : [d1, d2]

      @dice_1 = d1
      @dice_2 = d2
      @available_moves = moves
      @head_used = false

      apply_blocked_turn_if_needed!
      self
    end

    def reset!
      @board = Backgammon::Board.initial

      @available_moves = []
      @dice_1 = 0
      @dice_2 = 0
      @current_turn = 0
      @head_used = false
      @white_borne_off = 0
      @black_borne_off = 0
      @status = 1
      @flash_alert = nil
      self
    end

    def apply_move!(from:, to:)
      color = current_color
      head_index = Backgammon::Rules.head_index_for(color)

      is_bearing_off = (to.to_i < 0)

      distance =
        if is_bearing_off
          unless Backgammon::Rules.all_checkers_in_home?(board, color)
            raise Backgammon::ForbiddenMove, "Bring all the checkers into the house!"
          end
          color == "white" ? (from - 11) : (from + 1)
        else
          (from - to) % 24
        end

      moves = Array(available_moves)
      move_index =
        if is_bearing_off
          Backgammon::Rules.find_bearing_off_dice_index(board, moves, distance, from, color)
        else
          moves.index(distance)
        end

      if move_index.nil?
        raise Backgammon::InvalidMove, "There is no dice value on #{distance}"
      end

      source_color = board.color_at(from)
      raise Backgammon::ForbiddenMove, "Wrong move of the opponent's checker!" if source_color != color

      # head rule
      if from == head_index
        count_in_head = board.count_at(from)
        is_double = (dice_1 == dice_2)
        is_first_turn_exception = is_double && (count_in_head == 14)
        if head_used && !is_first_turn_exception
          raise Backgammon::ForbiddenMove, "You can only take one checker from your head!"
        end
      end

      unless is_bearing_off
        if board.count_at(to) > 0 && board.color_at(to) != color
          raise Backgammon::ForbiddenMove, "The point is occupied by an opponent"
        end
      end

      next_board = board.dup
      next_board.decrement!(from)
      next_board.increment!(to, color:) unless is_bearing_off

      if Backgammon::Rules.creates_illegal_prime?(next_board, color)
        raise Backgammon::ForbiddenMove, "You cannot build a block of 6 checkers if your opponent has not yet passed it!"
      end

      # commit state
      @board = next_board
      moves.delete_at(move_index)
      @available_moves = moves
      @head_used = true if from == head_index

      if is_bearing_off
        if color == "white"
          @white_borne_off += 1
        else
          @black_borne_off += 1
        end
        @status = 2 if @white_borne_off == 15 || @black_borne_off == 15
      end

      @current_turn = (@current_turn + 1) % 2 if @available_moves.empty?

      apply_blocked_turn_if_needed!
      self
    end

    def apply_to_record!(game)
      game.board_state = board.to_json
      game.available_moves = available_moves
      game.dice_1 = dice_1
      game.dice_2 = dice_2
      game.current_turn = current_turn
      game.head_used = head_used
      game.white_borne_off = white_borne_off
      game.black_borne_off = black_borne_off
      game.status = status
      game
    end

    private

    def apply_blocked_turn_if_needed!
      return self if available_moves.empty?

      color = current_color
      has_any = Backgammon::Rules.any_legal_moves?(
        board:,
        color:,
        available_moves:,
        dice_1:,
        dice_2:,
        head_used:
      )

      return self if has_any

      @available_moves = []
      @current_turn = (@current_turn + 1) % 2
      @flash_alert = "No possible moves! Pass move."
      self
    end
  end
end