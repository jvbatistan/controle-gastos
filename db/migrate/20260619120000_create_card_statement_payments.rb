class CreateCardStatementPayments < ActiveRecord::Migration[6.1]
  def change
    create_table :card_statement_payments do |t|
      t.references :card_statement, null: false, foreign_key: true
      t.references :original_transaction, foreign_key: { to_table: :transactions }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.datetime :paid_at, null: false
      t.string :description
      t.string :source

      t.timestamps
    end

    add_index :card_statement_payments, :paid_at
    add_index :card_statement_payments, :original_transaction_id, unique: true, where: "original_transaction_id IS NOT NULL", name: "idx_statement_payments_original_transaction"
    add_index :card_statement_payments, [:card_statement_id, :amount, :paid_at, :description], unique: true, name: "idx_statement_payments_dedup"
  end
end
