# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_12_124410) do
  create_table "games", force: :cascade do |t|
    t.json "available_moves"
    t.integer "black_borne_off"
    t.json "board_state"
    t.datetime "created_at", null: false
    t.integer "current_turn"
    t.integer "dice_1"
    t.integer "dice_2"
    t.boolean "head_used"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.integer "white_borne_off"
  end
end
