class CreateAccountTransfers < ActiveRecord::Migration[6.1]
  def change
    create_table :account_transfers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :from_account, null: false, foreign_key: { to_table: :accounts }
      t.references :to_account, null: false, foreign_key: { to_table: :accounts }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :transferred_on, null: false
      t.string :description
      t.text :note
      t.integer :status, null: false, default: 0

      t.timestamps

      t.index :transferred_on
      t.index %i[user_id transferred_on]
    end

    add_check_constraint :account_transfers, "amount > 0", name: "account_transfers_amount_positive"
    add_check_constraint :account_transfers, "from_account_id <> to_account_id", name: "account_transfers_accounts_distinct"
  end
end
