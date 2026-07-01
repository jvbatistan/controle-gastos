class CreateAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :kind, null: false
      t.decimal :initial_balance, precision: 12, scale: 2, null: false, default: 0
      t.date :initial_balance_date, null: false
      t.datetime :archived_at

      t.timestamps
    end

    add_index :accounts, :archived_at
    add_index :accounts, [:user_id, :name], unique: true
  end
end
