class Game < ApplicationRecord
  ReplayView = Struct.new(
    :id,
    :board_state,
    :available_moves,
    :dice_1,
    :dice_2,
    :current_turn,
    :head_used,
    :white_borne_off,
    :black_borne_off,
    :status,
    :dice_stats,
    :move_history_entries,
    keyword_init: true
  ) do
    def undo_available? = false
    def legal_moves_map = {}
  end

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

  def move_history_entries
    return move_history.select { |entry| entry.is_a?(Hash) } if move_history.is_a?(Array)
    return [move_history] if move_history.is_a?(Hash)

    []
  end

  def append_move_history!(entry)
    history = move_history_entries
    history << entry
    self.move_history = history
  end

  def clear_move_history!
    self.move_history = nil
  end

  def replay_view(step)
    history = move_history_entries
    total = history.size
    bounded_step = [[step.to_i, 0].max, total].min
    snapshot = snapshot_for_replay_step(bounded_step, history)

    [
      ReplayView.new(
        id: id,
        board_state: snapshot["board_state"],
        available_moves: Array(snapshot["available_moves"]).map(&:to_i),
        dice_1: snapshot["dice_1"].to_i,
        dice_2: snapshot["dice_2"].to_i,
        current_turn: snapshot["current_turn"].to_i,
        head_used: !!snapshot["head_used"],
        white_borne_off: snapshot["white_borne_off"].to_i,
        black_borne_off: snapshot["black_borne_off"].to_i,
        status: snapshot["status"].to_i,
        dice_stats: snapshot["dice_stats"],
        move_history_entries: history
      ),
      bounded_step,
      total
    ]
  end

  def legal_moves_map
    domain_state.legal_destinations_by_from
  rescue StandardError
    {}
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

  private

  def snapshot_for_replay_step(step, history)
    return current_snapshot if history.empty?
    return history[step - 1]["after"] if step.positive?

    history.first["before"] || current_snapshot
  end

  def current_snapshot
    domain_state.snapshot
  end
end
