class AddCategoryToDebts < ActiveRecord::Migration[6.0]
  def change
    add_reference :debts, :category, foreign_key: true, null: true
  end
end
