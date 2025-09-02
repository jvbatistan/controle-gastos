class AddExpenseTypeToDebts < ActiveRecord::Migration[6.0]
  def change
    add_column :debts, :expense_type, :integer
  end
end
