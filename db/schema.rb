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

ActiveRecord::Schema.define(version: 2026_05_11_203000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "supabase_vault"
  enable_extension "uuid-ossp"

  create_table "card_statements", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.date "billing_statement", null: false
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "paid_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "paid_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "ignored_at"
    t.index ["card_id", "billing_statement"], name: "index_card_statements_on_card_id_and_billing_statement", unique: true
    t.index ["card_id"], name: "index_card_statements_on_card_id"
    t.index ["ignored_at"], name: "index_card_statements_on_ignored_at"
  end

  create_table "cards", force: :cascade do |t|
    t.string "name"
    t.integer "due_date"
    t.integer "closing_date"
    t.integer "limit"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.integer "due_day"
    t.integer "closing_day"
    t.index ["user_id"], name: "index_cards_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "icon"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "classification_suggestions", force: :cascade do |t|
    t.bigint "financial_transaction_id", null: false
    t.bigint "suggested_category_id"
    t.float "confidence", default: 1.0, null: false
    t.integer "source", default: 0, null: false
    t.datetime "accepted_at"
    t.datetime "rejected_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.index ["financial_transaction_id", "accepted_at", "rejected_at"], name: "idx_suggestions_pending"
    t.index ["financial_transaction_id"], name: "index_classification_suggestions_on_financial_transaction_id"
    t.index ["suggested_category_id"], name: "index_classification_suggestions_on_suggested_category_id"
    t.index ["user_id"], name: "index_classification_suggestions_on_user_id"
  end

  create_table "merchant_aliases", force: :cascade do |t|
    t.string "normalized_merchant", null: false
    t.bigint "category_id", null: false
    t.float "confidence", default: 1.0, null: false
    t.integer "source", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_merchant_aliases_on_category_id"
    t.index ["user_id", "normalized_merchant"], name: "index_merchant_aliases_on_user_id_and_normalized_merchant", unique: true
    t.index ["user_id"], name: "index_merchant_aliases_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.string "description", null: false
    t.decimal "value", precision: 12, scale: 2, null: false
    t.date "date", null: false
    t.integer "kind", default: 1, null: false
    t.integer "source", default: 0, null: false
    t.boolean "paid", default: false, null: false
    t.text "note"
    t.string "responsible"
    t.bigint "card_id"
    t.bigint "category_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.date "billing_statement"
    t.string "installment_group_id"
    t.integer "installment_number"
    t.integer "installments_count"
    t.bigint "user_id", null: false
    t.datetime "archived_at"
    t.datetime "payment_ignored_at"
    t.index ["archived_at"], name: "index_transactions_on_archived_at"
    t.index ["card_id"], name: "index_transactions_on_card_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["installment_group_id", "installment_number"], name: "idx_transactions_installment_group_number", unique: true
    t.index ["installment_group_id"], name: "index_transactions_on_installment_group_id"
    t.index ["kind", "date"], name: "index_transactions_on_kind_and_date"
    t.index ["kind"], name: "index_transactions_on_kind"
    t.index ["payment_ignored_at"], name: "index_transactions_on_payment_ignored_at"
    t.index ["source", "date"], name: "index_transactions_on_source_and_date"
    t.index ["source"], name: "index_transactions_on_source"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "(email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)", name: "users_email_change_confirm_status_check"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "card_statements", "cards"
  add_foreign_key "cards", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "classification_suggestions", "categories", column: "suggested_category_id"
  add_foreign_key "classification_suggestions", "transactions", column: "financial_transaction_id"
  add_foreign_key "classification_suggestions", "users"
  add_foreign_key "merchant_aliases", "categories"
  add_foreign_key "merchant_aliases", "users"
  add_foreign_key "transactions", "cards"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "users"
end
