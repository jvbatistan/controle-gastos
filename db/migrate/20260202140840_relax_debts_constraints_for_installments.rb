class RelaxDebtsConstraintsForInstallments < ActiveRecord::Migration[6.0]
  def change
    change_column_null :debts, :financial_transaction_id, false
    change_column_null :debts, :card_id, true
    change_column_null :debts, :category_id, true
    change_column_null :debts, :description, true
    change_column_null :debts, :value, true
    change_column_null :debts, :transaction_date, true
    change_column_null :debts, :billing_statement, true if column_exists?(:debts, :billing_statement)
    change_column_null :debts, :responsible, true if column_exists?(:debts, :responsible)
    change_column_null :debts, :expense_type, true if column_exists?(:debts, :expense_type)
  end
end
