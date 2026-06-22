class AddRefundToTransactions < ActiveRecord::Migration[6.1]
  def up
    add_column :transactions, :refund, :boolean, default: false, null: false

    execute <<~SQL.squish
      UPDATE transactions
      SET refund = TRUE
      WHERE value < 0
        AND description ~* '(ESTORNO|REEMBOLSO|CREDITO|CRÉDITO)'
        AND description !~* '(PAGAMENTO[[:space:]]+RECEBIDO|LIBERAR[[:space:]]+LIMITE)'
    SQL

    execute <<~SQL.squish
      UPDATE transactions
      SET value = ABS(value)
      WHERE value < 0
    SQL

    execute <<~SQL.squish
      UPDATE transactions
      SET installment_group_id = NULL,
          installment_number = NULL,
          installments_count = NULL
      WHERE refund = TRUE
    SQL
  end

  def down
    remove_column :transactions, :refund
  end
end
