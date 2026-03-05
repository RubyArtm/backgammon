require "test_helper"

class Backgammon::GameStateTest < ActiveSupport::TestCase
  test "reset sets initial state" do
    state = Backgammon::GameState.new(
      board: Backgammon::Board.initial,
      available_moves: [6],
      dice_1: 6,
      dice_2: 6,
      current_turn: 1,
      head_used: true,
      white_borne_off: 3,
      black_borne_off: 2,
      status: 2
    )

    state.reset!

    assert_equal [], state.available_moves
    assert_equal 0, state.dice_1
    assert_equal 0, state.dice_2
    assert_equal 0, state.current_turn
    assert_equal false, state.head_used
    assert_equal 0, state.white_borne_off
    assert_equal 0, state.black_borne_off
    assert_equal 1, state.status
    assert_equal "white", state.board.color_at(11)
    assert_equal 15, state.board.count_at(11)
  end
end