require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "roll_dice works for the game stored in session" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    post roll_dice_game_path(game)
    assert_response :redirect

    game.reload
    assert_operator game.dice_1, :>=, 1
    assert_operator game.dice_1, :<=, 6
    assert_operator game.dice_2, :>=, 1
    assert_operator game.dice_2, :<=, 6
    assert game.available_moves.present?
  end

  test "move is forbidden when session game_id mismatches params[:id]" do
    other_game = Game.create!
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    Game.find(match[1])

    post move_game_path(other_game),
         params: { from_index: 11, to_index: 7 },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :forbidden
  end

  test "reset works for the game stored in session" do
    get root_path
    assert_response :success
    match = response.body.match(%r{/games/(\d+)/roll_dice})
    game = Game.find(match[1])

    post roll_dice_game_path(game)
    assert_response :redirect

    post reset_game_path(game), params: { preserve_stats: false }
    assert_response :redirect

    game.reload
    assert_equal 0, game.dice_1
    assert_equal 0, game.dice_2
    assert_equal [], game.available_moves
    assert_equal 1, game.status
  end
end
