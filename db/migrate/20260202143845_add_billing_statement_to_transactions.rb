class AddBillingStatementToTransactions < ActiveRecord::Migration[6.0]
  def change
    add_column :transactions, :billing_statement, :date
  end
end
