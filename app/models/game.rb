class Game < ApplicationRecord
  before_create :setup_initial_board

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
  end
end