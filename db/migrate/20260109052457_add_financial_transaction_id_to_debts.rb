class AddFinancialTransactionIdToDebts < ActiveRecord::Migration[6.0]
  def change
    add_reference :debts, :financial_transaction, foreign_key: { to_table: :transactions }, index: true, null: true
  end
end
