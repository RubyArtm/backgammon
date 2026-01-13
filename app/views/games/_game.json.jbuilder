json.extract! game, :id, :status, :current_turn, :dice_1, :dice_2, :board_state, :created_at, :updated_at
json.url game_url(game, format: :json)
