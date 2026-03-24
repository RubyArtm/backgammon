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

  test "undo availability depends on turn and opponent roll state" do
    game = Game.create!

    refute game.undo_available?

    game.push_undo_snapshot!({ "current_turn" => 0 })
    assert game.undo_available?

    snapshot = game.pop_undo_snapshot!
    assert_equal 0, snapshot["current_turn"]
    refute game.undo_available?
  end

  test "replay view returns bounded step and snapshot data" do
    game = Game.create!
    before = game.domain_state.snapshot
    after = before.deep_dup
    after["current_turn"] = 1

    game.append_move_history!(
      {
        "from" => 11,
        "to" => 10,
        "color" => "white",
        "die" => 1,
        "before" => before,
        "after" => after
      }
    )

    replay_game, step, total = game.replay_view(99)

    assert_equal 1, step
    assert_equal 1, total
    assert_equal 1, replay_game.current_turn
    assert_equal false, replay_game.undo_available?
    assert_equal({}, replay_game.legal_moves_map)
  end
end
