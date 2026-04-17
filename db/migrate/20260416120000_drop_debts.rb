class DropDebts < ActiveRecord::Migration[6.1]
  def up
    drop_table :debts, if_exists: true
  end

  def down
    create_table :debts do |t|
      t.string :description
      t.decimal :value, precision: 12, scale: 2
      t.date :transaction_date
      t.date :billing_statement
      t.boolean :paid
      t.boolean :has_installment
      t.integer :current_installment
      t.integer :final_installment
      t.string :responsible
      t.integer :parent_id
      t.references :card, foreign_key: true
      t.text :note
      t.references :category, foreign_key: true
      t.integer :expense_type
      t.references :financial_transaction, null: false, foreign_key: { to_table: :transactions }
      t.timestamps
    end
  end
end
