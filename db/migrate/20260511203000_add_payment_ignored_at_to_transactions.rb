class AddPaymentIgnoredAtToTransactions < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :payment_ignored_at, :datetime
    add_index :transactions, :payment_ignored_at
  end
end
