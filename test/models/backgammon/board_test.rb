require "test_helper"

class Backgammon::BoardTest < ActiveSupport::TestCase
  test "initial board has 24 points and correct heads" do
    board = Backgammon::Board.initial

    assert_equal 24, board.to_json.size
    assert_equal "white", board.color_at(11)
    assert_equal 15, board.count_at(11)
    assert_equal "black", board.color_at(23)
    assert_equal 15, board.count_at(23)
  end
end