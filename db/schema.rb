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

ActiveRecord::Schema.define(version: 2025_05_12_003642) do

  create_table "cards", force: :cascade do |t|
    t.string "name"
    t.integer "due_date"
    t.integer "closing_date"
    t.integer "limit"
    t.string "image"
    t.string "color"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "debts", force: :cascade do |t|
    t.string "description"
    t.float "value"
    t.date "transaction_date"
    t.date "billing_statement"
    t.boolean "paid"
    t.boolean "has_installment"
    t.integer "current_installment"
    t.integer "final_installment"
    t.string "responsible"
    t.integer "parent_id"
    t.integer "card_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "note"
    t.integer "category_id"
    t.index ["card_id"], name: "index_debts_on_card_id"
    t.index ["category_id"], name: "index_debts_on_category_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object", limit: 1073741823
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "debts", "cards"
  add_foreign_key "debts", "categories"
end
