class AddUndoSnapshotToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :undo_snapshot, :json
  end
end
