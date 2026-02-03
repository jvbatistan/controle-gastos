class AddInstallmentsFieldsToTransactions < ActiveRecord::Migration[6.0]
  def change
    add_column :transactions, :installment_group_id, :string
    add_column :transactions, :installment_number, :integer
    add_column :transactions, :installments_count, :integer

    add_index :transactions, :installment_group_id
    add_index :transactions, [:installment_group_id, :installment_number], unique: true, name: "idx_transactions_installment_group_number"
  end
end
