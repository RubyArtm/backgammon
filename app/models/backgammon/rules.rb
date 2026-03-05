module Backgammon
  module Rules
    WHITE_PATH = [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12].freeze
    BLACK_PATH = [23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0].freeze

    module_function

    def path_for(color)
      color == "white" ? WHITE_PATH : BLACK_PATH
    end

    def opponent_color(color)
      color == "white" ? "black" : "white"
    end

    def head_index_for(color)
      color == "white" ? 11 : 23
    end

    def home_range_for(color)
      color == "white" ? (12..17) : (0..5)
    end

    def all_checkers_in_home?(board, color)
      home = home_range_for(color)
      board.each_index.all? do |i|
        c = board.color_at(i)
        n = board.count_at(i)
        n == 0 || c != color || home.include?(i)
      end
    end

    def creates_illegal_prime?(board, color)
      my_path  = path_for(color)
      opp_path = path_for(opponent_color(color))
      opp      = opponent_color(color)

      consecutive = 0
      my_path.each do |idx|
        if board.color_at(idx) == color && board.count_at(idx) > 0
          consecutive += 1
          next unless consecutive >= 6

          opp_idx_of_fence_end = opp_path.index(idx)
          remaining_opp_path = opp_path[(opp_idx_of_fence_end + 1)..] || []

          has_passed = remaining_opp_path.any? { |oidx| board.color_at(oidx) == opp && board.count_at(oidx) > 0 }
          return true unless has_passed
        else
          consecutive = 0
        end
      end

      false
    end

    def find_bearing_off_dice_index(board, moves, dist, from, color)
      moves = Array(moves)

      exact = moves.index(dist)
      return exact if exact

      bigger_idx = moves.index { |m| m > dist }
      return nil unless bigger_idx

      limit = (color == "white" ? 17 : 5)
      back_range = ((from + 1)..limit)

      has_checkers_behind = board.each_index.any? do |idx|
        back_range.include?(idx) && board.color_at(idx) == color && board.count_at(idx) > 0
      end

      has_checkers_behind ? nil : bigger_idx
    end

    def any_legal_moves?(board:, color:, available_moves:, dice_1:, dice_2:, head_used:)
      path = path_for(color)
      head_index = head_index_for(color)
      moves = Array(available_moves).uniq

      board.each_index do |from_idx|
        next unless board.color_at(from_idx) == color && board.count_at(from_idx) > 0

        moves.each do |dist|
          current_pos = path.index(from_idx)
          target_pos = current_pos + dist

          # bearing off
          if target_pos >= 24
            next unless all_checkers_in_home?(board, color)
            next unless find_bearing_off_dice_index(board, moves, dist, from_idx, color)
            return true
          end

          to_idx = path[target_pos]
          next if board.count_at(to_idx) > 0 && board.color_at(to_idx) != color

          if from_idx == head_index
            is_double = (dice_1 == dice_2)
            is_start_exception = is_double && board.count_at(from_idx) == 14
            next if head_used && !is_start_exception
          end

          simulated = board.dup
          simulated.decrement!(from_idx)
          simulated.increment!(to_idx, color:)
          next if creates_illegal_prime?(simulated, color)

          return true
        end
      end

      false
    end
  end
end