class AddHeadUsedToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :head_used, :boolean
  end
end
