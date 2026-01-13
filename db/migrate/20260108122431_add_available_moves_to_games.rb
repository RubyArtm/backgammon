class AddAvailableMovesToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :available_moves, :json
  end
end
