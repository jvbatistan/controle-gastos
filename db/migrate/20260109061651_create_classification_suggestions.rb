class CreateClassificationSuggestions < ActiveRecord::Migration[6.0]
  def change
    create_table :classification_suggestions do |t|
      t.references :financial_transaction, null: false, foreign_key: { to_table: :transactions }
      t.references :suggested_category, null: false, foreign_key: { to_table: :categories }
      t.float :confidence, null: false, default: 1.0
      t.integer :source, null: false, default: 0
      t.datetime :accepted_at
      t.datetime :rejected_at

      t.timestamps
    end

    add_index :classification_suggestions, [:financial_transaction_id, :accepted_at, :rejected_at], name: "idx_suggestions_pending"
  end
end
