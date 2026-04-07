class AddArchivedAtToTransactions < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :archived_at, :datetime
    add_index :transactions, :archived_at
  end
end
