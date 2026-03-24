require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "initializes dice statistics for both players" do
    game = Game.create!

    assert_equal 0, game.dice_stats.dig("white", "rolled", "1")
    assert_equal 0, game.dice_stats.dig("white", "used", "6")
    assert_equal 0, game.dice_stats.dig("white", "rolled", "total")
    assert_equal 0, game.dice_stats.dig("white", "used", "total")
    assert_equal 0, game.dice_stats.dig("white", "doubles", "4")
    assert_equal 0, game.dice_stats.dig("white", "doubles", "total")
    assert_equal 0, game.dice_stats.dig("black", "rolled", "3")
    assert_equal 0, game.dice_stats.dig("black", "used", "5")
    assert_equal 0, game.dice_stats.dig("black", "rolled", "total")
    assert_equal 0, game.dice_stats.dig("black", "used", "total")
    assert_equal 0, game.dice_stats.dig("black", "doubles", "2")
    assert_equal 0, game.dice_stats.dig("black", "doubles", "total")
  end
end
