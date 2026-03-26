require "test_helper"

class MoveErrorMessagesTest < ActionDispatch::IntegrationTest
  test "invalid dice value returns domain message instead of server error" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    game.update!(available_moves: [ 1 ], dice_1: 1, dice_2: 2, current_turn: 0)

    post move_game_path(game),
         params: { from_index: 11, to_index: 7 },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_match "There is no dice value on 4", response.body
  end

  test "occupied point by opponent returns domain message instead of server error" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    board = Backgammon::Board.from_json(game.board_state)
    board.increment!(10, color: "black")
    game.update!(board_state: board.to_json, available_moves: [ 1 ], dice_1: 1, dice_2: 2, current_turn: 0)

    post move_game_path(game),
         params: { from_index: 11, to_index: 10 },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :forbidden
    assert_match "The point is occupied by an opponent", response.body
  end
end
