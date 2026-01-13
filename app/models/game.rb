class Game < ApplicationRecord
  # Setting the initial state before creating a record in the database
  before_create :setup_initial_board

  def setup_initial_board
    # Create an array of 24 empty items
    # Each note: { 'color' => 'white'/'black'/nil, 'count' => 0 }
    initial_state = Array.new(24) { { color: nil, count: 0 } }

    # Backgammon setup:
    initial_state[11] = { color: 'white', count: 15 }
    initial_state[23] = { color: 'black', count: 15 }

    self.board_state = initial_state
    self.current_turn = 0 # The whites begin
    self.status = 1 # Instant "in game" status
    self.head_used = false
    self.white_borne_off = 0
    self.black_borne_off = 0
  end
end
