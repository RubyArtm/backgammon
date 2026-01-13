class AddScoreToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :white_borne_off, :integer
    add_column :games, :black_borne_off, :integer
  end
end
