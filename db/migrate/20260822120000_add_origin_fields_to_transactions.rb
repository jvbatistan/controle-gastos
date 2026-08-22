class AddOriginFieldsToTransactions < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :purchase_date, :date
    add_column :transactions, :original_value, :decimal, precision: 12, scale: 2
  end
end
