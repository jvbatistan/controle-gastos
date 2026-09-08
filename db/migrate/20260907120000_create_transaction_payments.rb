class CreateTransactionPayments < ActiveRecord::Migration[6.1]
  def change
    create_table :transaction_payments do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :settled_on, null: false
      t.timestamps
    end

    add_index :transaction_payments, %i[account_id settled_on]
    add_check_constraint :transaction_payments, 'amount > 0', name: 'transaction_payments_amount_positive'
  end
end
