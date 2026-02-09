class AddUserRefToCoreTables < ActiveRecord::Migration[6.0]
  def change
    add_reference :cards, :user, foreign_key: true, index: true, null: true
    add_reference :categories, :user, foreign_key: true, index: true, null: true
    add_reference :transactions, :user, foreign_key: true, index: true, null: true
    add_reference :merchant_aliases, :user, foreign_key: true, index: true, null: true
    add_reference :classification_suggestions, :user, foreign_key: true, index: true, null: true
  end
end
