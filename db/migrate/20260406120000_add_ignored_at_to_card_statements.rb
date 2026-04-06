class AddIgnoredAtToCardStatements < ActiveRecord::Migration[6.1]
  def change
    add_column :card_statements, :ignored_at, :datetime
    add_index :card_statements, :ignored_at
  end
end
