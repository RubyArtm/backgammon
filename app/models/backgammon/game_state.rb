module Backgammon
  class GameState
    attr_reader :board, :available_moves, :dice_1, :dice_2, :current_turn,
                :head_used, :white_borne_off, :black_borne_off, :status, :flash_alert, :dice_stats, :last_used_die

    def self.empty_dice_stats
      {
        "white" => {
          "rolled" => default_counter,
          "used" => default_counter,
          "doubles" => default_counter
        },
        "black" => {
          "rolled" => default_counter,
          "used" => default_counter,
          "doubles" => default_counter
        }
      }
    end

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
        status: game.status.to_i,
        dice_stats: game.dice_stats
      )
    end

    def initialize(board:, available_moves:, dice_1:, dice_2:, current_turn:, head_used:, white_borne_off:, black_borne_off:, status:, dice_stats:)
      @board = board
      @available_moves = available_moves
      @dice_1 = dice_1
      @dice_2 = dice_2
      @current_turn = current_turn
      @head_used = head_used
      @white_borne_off = white_borne_off
      @black_borne_off = black_borne_off
      @status = status
      @dice_stats = self.class.normalize_dice_stats(dice_stats)
      @flash_alert = nil
      @last_used_die = nil
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
      @last_used_die = nil
      moves.each { |value| increment_counter!(current_color, "rolled", value) }
      increment_double_counter!(current_color, d1) if d1 == d2

      apply_blocked_turn_if_needed!
      self
    end

    def reset!(preserve_stats: false)
      @board = Backgammon::Board.initial

      @available_moves = []
      @dice_1 = 0
      @dice_2 = 0
      @current_turn = 0
      @head_used = false
      @white_borne_off = 0
      @black_borne_off = 0
      @status = 1
      @dice_stats = self.class.empty_dice_stats unless preserve_stats
      @flash_alert = nil
      @last_used_die = nil
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
      used_value = moves[move_index]
      moves.delete_at(move_index)
      @available_moves = moves
      @head_used = true if from == head_index
      increment_counter!(color, "used", used_value)
      @last_used_die = used_value

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
      game.dice_stats = dice_stats
      game
    end

    def snapshot
      {
        "board_state" => board.to_json,
        "available_moves" => available_moves.deep_dup,
        "dice_1" => dice_1,
        "dice_2" => dice_2,
        "current_turn" => current_turn,
        "head_used" => head_used,
        "white_borne_off" => white_borne_off,
        "black_borne_off" => black_borne_off,
        "status" => status,
        "dice_stats" => dice_stats.deep_dup
      }
    end

    def restore_from_snapshot!(input)
      snapshot = input.is_a?(Hash) ? input : {}

      @board = Backgammon::Board.from_json(read_snapshot(snapshot, "board_state"))
      @available_moves = Array(read_snapshot(snapshot, "available_moves")).map(&:to_i)
      @dice_1 = read_snapshot(snapshot, "dice_1").to_i
      @dice_2 = read_snapshot(snapshot, "dice_2").to_i
      @current_turn = read_snapshot(snapshot, "current_turn").to_i
      @head_used = !!read_snapshot(snapshot, "head_used")
      @white_borne_off = read_snapshot(snapshot, "white_borne_off").to_i
      @black_borne_off = read_snapshot(snapshot, "black_borne_off").to_i
      @status = read_snapshot(snapshot, "status").to_i
      @dice_stats = self.class.normalize_dice_stats(read_snapshot(snapshot, "dice_stats"))
      @flash_alert = nil
      @last_used_die = nil
      self
    end

    def legal_destinations_by_from
      return {} if available_moves.empty?
      return {} if status == 2

      color = current_color
      path = Backgammon::Rules.path_for(color)
      head_index = Backgammon::Rules.head_index_for(color)
      house_index = color == "white" ? -1 : -2
      moves = Array(available_moves).uniq
      map = Hash.new { |h, k| h[k] = [] }

      board.each_index do |from_idx|
        next unless board.color_at(from_idx) == color && board.count_at(from_idx) > 0

        moves.each do |distance|
          current_pos = path.index(from_idx)
          next if current_pos.nil?

          to_idx, is_bearing_off = legal_target_for(
            from_idx:,
            distance:,
            color:,
            path:,
            moves:,
            house_index:
          )
          next if to_idx.nil?
          next unless legal_from_head?(from_idx, head_index)
          next unless legal_after_prime_check?(from_idx:, to_idx:, color:, is_bearing_off:)

          map[from_idx] << to_idx unless map[from_idx].include?(to_idx)
        end
      end

      map.transform_keys(&:to_s).transform_values { |targets| targets.map(&:to_s) }
    end

    private

    def self.default_counter
      {
        "1" => 0,
        "2" => 0,
        "3" => 0,
        "4" => 0,
        "5" => 0,
        "6" => 0,
        "total" => 0
      }
    end
    private_class_method :default_counter

    def self.normalize_dice_stats(input)
      stats = empty_dice_stats
      return stats unless input.is_a?(Hash)

      %w[white black].each do |color|
        color_data = input[color]
        next unless color_data.is_a?(Hash)

        %w[rolled used doubles].each do |kind|
          kind_data = color_data[kind]
          next unless kind_data.is_a?(Hash)

          ("1".."6").each do |die|
            stats[color][kind][die] = kind_data[die].to_i if kind_data.key?(die)
          end

          stats[color][kind]["total"] =
            if kind_data.key?("total")
              kind_data["total"].to_i
            elsif kind == "doubles"
              counter_count(stats[color][kind])
            else
              counter_total(stats[color][kind])
            end
        end
      end

      stats
    end

    def increment_counter!(color, kind, value)
      numeric_value = value.to_i
      @dice_stats[color][kind][numeric_value.to_s] += 1
      @dice_stats[color][kind]["total"] += numeric_value
    end

    def increment_double_counter!(color, value)
      numeric_value = value.to_i
      @dice_stats[color]["doubles"][numeric_value.to_s] += 1
      @dice_stats[color]["doubles"]["total"] += 1
    end

    def self.counter_total(counter)
      ("1".."6").sum { |die| counter[die].to_i * die.to_i }
    end
    private_class_method :counter_total

    def self.counter_count(counter)
      ("1".."6").sum { |die| counter[die].to_i }
    end
    private_class_method :counter_count

    def read_snapshot(snapshot, key)
      snapshot[key] || snapshot[key.to_sym]
    end

    def legal_target_for(from_idx:, distance:, color:, path:, moves:, house_index:)
      target_pos = path.index(from_idx).to_i + distance
      if target_pos >= 24
        return [nil, true] unless Backgammon::Rules.all_checkers_in_home?(board, color)
        return [nil, true] unless Backgammon::Rules.find_bearing_off_dice_index(board, moves, distance, from_idx, color)

        return [house_index, true]
      end

      to_idx = path[target_pos]
      return [nil, false] if board.count_at(to_idx) > 0 && board.color_at(to_idx) != color

      [to_idx, false]
    end

    def legal_from_head?(from_idx, head_index)
      return true unless from_idx == head_index

      count_in_head = board.count_at(from_idx)
      is_double = (dice_1 == dice_2)
      is_first_turn_exception = is_double && (count_in_head == 14)
      !head_used || is_first_turn_exception
    end

    def legal_after_prime_check?(from_idx:, to_idx:, color:, is_bearing_off:)
      simulated = board.dup
      simulated.decrement!(from_idx)
      simulated.increment!(to_idx, color:) unless is_bearing_off
      !Backgammon::Rules.creates_illegal_prime?(simulated, color)
    end

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
