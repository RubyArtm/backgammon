class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.integer :status
      t.integer :current_turn
      t.integer :dice_1
      t.integer :dice_2
      t.json :board_state

      t.timestamps
    end
  end
end
