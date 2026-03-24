class AddMoveHistoryToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :move_history, :json
  end
end
