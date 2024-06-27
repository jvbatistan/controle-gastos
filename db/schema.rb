# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_09_01_153415) do

  create_table "cards", force: :cascade do |t|
    t.string "name"
    t.integer "pay_day"
    t.integer "limit"
    t.string "image"
    t.string "color"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "expenses", force: :cascade do |t|
    t.string "description"
    t.float "value"
    t.string "month"
    t.string "year"
    t.boolean "paid"
    t.boolean "has_installment"
    t.integer "current_installment"
    t.integer "final_installment"
    t.string "responsible"
    t.integer "card_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["card_id"], name: "index_expenses_on_card_id"
  end

  add_foreign_key "expenses", "cards"
end
