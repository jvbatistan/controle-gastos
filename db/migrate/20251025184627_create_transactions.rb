class CreateTransactions < ActiveRecord::Migration[6.0]
  def change
    create_table :transactions do |t|
      t.string :description, null: false
      t.decimal :value, null: false, precision: 12, scale: 2
      t.date :date, null: false
      
      # kind: income (entrada) | expense (saída)
      t.integer :kind, null: false, default: 1
      
      # source: de onde vem/para onde vai (cartão, dinheiro, banco)
      t.integer :source, null: false, default: 0
      
      # pago: faz sentido principalmente para despesas
      t.boolean :paid, null: false, default: false

      t.text :note
      t.string :responsible

      t.references :card, null: true, foreign_key: true
      t.references :category, null: true, foreign_key: true

      t.timestamps
    end

    add_index :transactions, :date
    add_index :transactions, :kind
    add_index :transactions, :source
    add_index :transactions, [:kind, :date]
    add_index :transactions, [:source, :date]
  end
end
