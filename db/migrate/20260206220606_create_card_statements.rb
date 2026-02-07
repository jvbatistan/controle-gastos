class CreateCardStatements < ActiveRecord::Migration[6.0]
  def change
    create_table :card_statements do |t|
      t.references :card, null: false, foreign_key: true

      # representa o mês da fatura (use sempre o 1º dia do mês)
      t.date :billing_statement, null: false

      # total do mês (pode ser recalculado, mas é útil cachear)
      t.decimal :total_amount, precision: 12, scale: 2, null: false, default: 0

      # quanto já foi pago na fatura (pagamentos parciais acumulam aqui)
      t.decimal :paid_amount, precision: 12, scale: 2, null: false, default: 0

      # opcional: quando ficou totalmente paga
      t.datetime :paid_at

      t.timestamps
    end

    add_index :card_statements, [:card_id, :billing_statement], unique: true
  end
end
