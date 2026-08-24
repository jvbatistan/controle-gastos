class AddSettlementFieldsToTransactions < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :settled_on, :date
    add_column :transactions, :settled_value, :decimal, precision: 12, scale: 2
  end
end
