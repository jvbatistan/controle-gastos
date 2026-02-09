class EnforceNotNullUserOnOwnedTables < ActiveRecord::Migration[6.0]
  def change
    change_column_null :cards, :user_id, false
    change_column_null :categories, :user_id, false
    change_column_null :transactions, :user_id, false
    change_column_null :merchant_aliases, :user_id, false
    change_column_null :classification_suggestions, :user_id, false
  end
end