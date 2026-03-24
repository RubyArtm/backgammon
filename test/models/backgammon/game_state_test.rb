require "test_helper"

class Backgammon::GameStateTest < ActiveSupport::TestCase
  def build_state(**overrides)
    defaults = {
      board: Backgammon::Board.initial,
      available_moves: [],
      dice_1: 0,
      dice_2: 0,
      current_turn: 0,
      head_used: false,
      white_borne_off: 0,
      black_borne_off: 0,
      status: 1,
      dice_stats: Backgammon::GameState.empty_dice_stats
    }

    Backgammon::GameState.new(**defaults.merge(overrides))
  end

  test "reset sets initial state" do
    state = build_state(
      available_moves: [6],
      dice_1: 6,
      dice_2: 6,
      current_turn: 1,
      head_used: true,
      white_borne_off: 3,
      black_borne_off: 2,
      status: 2,
      dice_stats: {
        "white" => { "rolled" => { "1" => 2 }, "used" => { "1" => 1 } },
        "black" => { "rolled" => { "1" => 3 }, "used" => { "1" => 2 } }
      }
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
    assert_equal 0, state.dice_stats.dig("white", "rolled", "1")
    assert_equal 0, state.dice_stats.dig("black", "used", "1")
    assert_equal 0, state.dice_stats.dig("white", "rolled", "total")
    assert_equal 0, state.dice_stats.dig("black", "used", "total")
    assert_equal "white", state.board.color_at(11)
    assert_equal 15, state.board.count_at(11)
  end

  test "roll_dice increments rolled counter even when turn is blocked" do
    blocked_points = Array.new(24) { { color: nil, count: 0 } }
    blocked_points[11] = { color: "white", count: 15 }
    blocked_points[10] = { color: "black", count: 8 }
    blocked_points[9] = { color: "black", count: 7 }
    state = build_state(board: Backgammon::Board.new(blocked_points))

    rand_values = [1, 2]
    state.define_singleton_method(:rand) { |*| rand_values.shift }
    state.roll_dice!

    assert_equal 1, state.dice_stats.dig("white", "rolled", "1")
    assert_equal 1, state.dice_stats.dig("white", "rolled", "2")
    assert_equal 3, state.dice_stats.dig("white", "rolled", "total")
    assert_equal 0, state.dice_stats.dig("white", "used", "1")
    assert_equal 0, state.dice_stats.dig("white", "used", "2")
    assert_equal 0, state.dice_stats.dig("white", "used", "total")
    assert_equal 0, state.dice_stats.dig("white", "doubles", "1")
    assert_equal 0, state.dice_stats.dig("white", "doubles", "total")
    assert_equal [], state.available_moves
    assert_equal 1, state.current_turn
  end

  test "roll_dice increments rolled counter four times for doubles" do
    state = build_state

    rand_values = [4, 4]
    state.define_singleton_method(:rand) { |*| rand_values.shift }
    state.roll_dice!

    assert_equal [4, 4, 4, 4], state.available_moves
    assert_equal 4, state.dice_stats.dig("white", "rolled", "4")
    assert_equal 16, state.dice_stats.dig("white", "rolled", "total")
    assert_equal 1, state.dice_stats.dig("white", "doubles", "4")
    assert_equal 0, state.dice_stats.dig("white", "doubles", "3")
    assert_equal 1, state.dice_stats.dig("white", "doubles", "total")
  end

  test "apply_move increments used counter only for consumed die value" do
    state = build_state(available_moves: [1, 2], dice_1: 1, dice_2: 2)

    state.apply_move!(from: 11, to: 10)

    assert_equal 1, state.dice_stats.dig("white", "used", "1")
    assert_equal 0, state.dice_stats.dig("white", "used", "2")
    assert_equal 1, state.dice_stats.dig("white", "used", "total")
    assert_equal 1, state.last_used_die
  end

  test "legal destinations map is returned for current turn" do
    state = build_state(available_moves: [1, 2], dice_1: 1, dice_2: 2)

    map = state.legal_destinations_by_from

    assert_equal %w[10 9], map["11"].sort
    assert_nil map["10"]
  end

  test "reset with preserve_stats keeps dice statistics" do
    state = build_state(
      dice_stats: {
        "white" => {
          "rolled" => { "6" => 3, "total" => 18 },
          "used" => { "6" => 1, "total" => 6 },
          "doubles" => { "6" => 2, "total" => 2 }
        },
        "black" => {
          "rolled" => { "2" => 4, "total" => 8 },
          "used" => { "2" => 2, "total" => 4 },
          "doubles" => { "2" => 1, "total" => 1 }
        }
      }
    )

    state.reset!(preserve_stats: true)

    assert_equal 3, state.dice_stats.dig("white", "rolled", "6")
    assert_equal 18, state.dice_stats.dig("white", "rolled", "total")
    assert_equal 2, state.dice_stats.dig("white", "doubles", "6")
    assert_equal 2, state.dice_stats.dig("white", "doubles", "total")
    assert_equal 4, state.dice_stats.dig("black", "rolled", "2")
    assert_equal 8, state.dice_stats.dig("black", "rolled", "total")
  end

  test "restore_from_snapshot reverts board and stats after move" do
    state = build_state(available_moves: [1], dice_1: 1, dice_2: 2)
    snapshot = state.snapshot

    state.apply_move!(from: 11, to: 10)
    assert_equal 1, state.dice_stats.dig("white", "used", "1")
    assert_equal 14, state.board.count_at(11)

    state.restore_from_snapshot!(snapshot)

    assert_equal 15, state.board.count_at(11)
    assert_equal 0, state.board.count_at(10)
    assert_equal [1], state.available_moves
    assert_equal 0, state.dice_stats.dig("white", "used", "1")
    assert_equal 0, state.dice_stats.dig("white", "used", "total")
  end
end
