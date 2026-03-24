class Game < ApplicationRecord
  before_create :setup_initial_board

  def self.initial_dice_stats
    {
      "white" => {
        "rolled" => default_dice_counter,
        "used" => default_dice_counter,
        "doubles" => default_double_counter
      },
      "black" => {
        "rolled" => default_dice_counter,
        "used" => default_dice_counter,
        "doubles" => default_double_counter
      }
    }
  end

  def domain_state
    Backgammon::GameState.from_record(self)
  end

  def setup_initial_board
    self.board_state = Backgammon::Board.initial.to_json
    self.current_turn = 0
    self.status = 1
    self.head_used = false
    self.white_borne_off = 0
    self.black_borne_off = 0
    self.available_moves = []
    self.dice_1 = 0
    self.dice_2 = 0
    self.dice_stats = self.class.initial_dice_stats
    self.undo_snapshot = nil
  end

  def undo_available?
    undo_stack.any?
  end

  def undo_stack
    case undo_snapshot
    when Array
      undo_snapshot.select { |item| item.is_a?(Hash) }
    when Hash
      [undo_snapshot]
    else
      []
    end
  end

  def push_undo_snapshot!(snapshot)
    stack = undo_stack
    stack << snapshot
    self.undo_snapshot = stack
  end

  def pop_undo_snapshot!
    stack = undo_stack
    snapshot = stack.pop
    self.undo_snapshot = stack.presence
    snapshot
  end

  def clear_undo_history!
    self.undo_snapshot = nil
  end

  def self.default_dice_counter
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

  def self.default_double_counter
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
  private_class_method :default_dice_counter
  private_class_method :default_double_counter

end
