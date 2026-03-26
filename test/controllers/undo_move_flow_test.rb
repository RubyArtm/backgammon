require "test_helper"

class UndoMoveFlowTest < ActionDispatch::IntegrationTest
  test "undo move restores previous position and dice stats" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    game.update!(available_moves: [ 1 ], dice_1: 1, dice_2: 2, current_turn: 0)

    initial_board = game.board_state

    post move_game_path(game), params: { from_index: 11, to_index: 10 }
    assert_response :redirect

    game.reload
    assert_equal 1, game.undo_stack.size
    assert_equal 1, game.move_history_entries.size
    assert_equal 1, game.dice_stats.dig("white", "used", "1")
    assert_equal 1, Backgammon::Board.from_json(game.board_state).count_at(10)

    post undo_move_game_path(game)
    assert_response :redirect

    game.reload
    assert_equal 0, game.undo_stack.size
    assert_equal 1, game.move_history_entries.size
    assert_equal initial_board, game.board_state
    assert_equal 0, game.dice_stats.dig("white", "used", "1")
    assert_equal 0, game.dice_stats.dig("white", "used", "total")
  end

  test "undo can be applied multiple times before opponent rolls" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    game.update!(available_moves: [ 1, 2 ], dice_1: 1, dice_2: 2, current_turn: 0)

    post move_game_path(game), params: { from_index: 11, to_index: 10 }
    assert_response :redirect

    post move_game_path(game), params: { from_index: 10, to_index: 8 }
    assert_response :redirect

    game.reload
    assert_equal 2, game.undo_stack.size
    assert_equal 2, game.move_history_entries.size
    assert_equal 1, game.current_turn
    assert_equal 3, game.dice_stats.dig("white", "used", "total")

    post undo_move_game_path(game)
    assert_response :redirect

    game.reload
    board = Backgammon::Board.from_json(game.board_state)
    assert_equal 1, game.undo_stack.size
    assert_equal 0, game.current_turn
    assert_equal [ 2 ], game.available_moves
    assert_equal 1, board.count_at(10)
    assert_equal 0, board.count_at(8)
    assert_equal 1, game.dice_stats.dig("white", "used", "1")
    assert_equal 1, game.dice_stats.dig("white", "used", "total")

    post undo_move_game_path(game)
    assert_response :redirect

    game.reload
    board = Backgammon::Board.from_json(game.board_state)
    assert_equal 0, game.undo_stack.size
    assert_equal 2, game.move_history_entries.size
    assert_equal 0, game.current_turn
    assert_equal [ 1, 2 ], game.available_moves
    assert_equal 15, board.count_at(11)
    assert_equal 0, board.count_at(10)
    assert_equal 0, game.dice_stats.dig("white", "used", "1")
    assert_equal 0, game.dice_stats.dig("white", "used", "total")
  end

  test "undo is forbidden after opponent rolled dice" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    game.update!(available_moves: [ 1 ], dice_1: 1, dice_2: 2, current_turn: 0)

    post move_game_path(game), params: { from_index: 11, to_index: 10 }
    assert_response :redirect

    post roll_dice_game_path(game)
    assert_response :redirect

    game.reload
    assert_equal 0, game.undo_stack.size

    post undo_move_game_path(game),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :unprocessable_entity
    assert_match "Undo is available only before opponent rolls the dice.", response.body
    assert_match "flash-message", response.body
  end

  test "history replay step renders successfully" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    game.update!(available_moves: [ 1 ], dice_1: 1, dice_2: 2, current_turn: 0)

    post move_game_path(game), params: { from_index: 11, to_index: 10 }
    assert_response :redirect

    get root_path(replay_step: 1)
    assert_response :success
    assert_match "Replay mode", response.body
  end
end
