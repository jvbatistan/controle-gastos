class ConvertNubankJulyPaymentTransaction < ActiveRecord::Migration[6.1]
  class MigrationTransaction < ActiveRecord::Base
    self.table_name = "transactions"
  end

  class MigrationCardStatement < ActiveRecord::Base
    self.table_name = "card_statements"
  end

  class MigrationCardStatementPayment < ActiveRecord::Base
    self.table_name = "card_statement_payments"
  end

  TRANSACTION_ID = 641
  CARD_ID = 2
  PERIOD_START = Date.new(2026, 7, 1)
  PERIOD_END = PERIOD_START.end_of_month

  def up
    transaction = MigrationTransaction.find_by(
      id: TRANSACTION_ID,
      card_id: CARD_ID,
      description: "PAGAMENTO",
      value: BigDecimal("30.00"),
      refund: false
    )
    return say("Skipping payment conversion: audited transaction ##{TRANSACTION_ID} no longer matches") if transaction.nil?

    statement = MigrationCardStatement.where(card_id: CARD_ID, billing_statement: PERIOD_START..PERIOD_END).first
    return say("Skipping payment conversion: Nubank statement 07/2026 was not found") if statement.nil?

    say "Converting transaction ##{TRANSACTION_ID} PAGAMENTO 30.00 to statement payment"
    payment = MigrationCardStatementPayment.find_or_initialize_by(original_transaction_id: transaction.id)
    payment.card_statement_id = statement.id
    payment.amount = transaction.value.to_d.abs
    payment.paid_at = transaction.date.to_time.in_time_zone
    payment.description = transaction.description
    payment.source = "converted_transaction"
    payment.save!

    transaction.update_columns(
      archived_at: transaction.archived_at || Time.current,
      payment_ignored_at: transaction.payment_ignored_at || Time.current,
      updated_at: Time.current
    )

    resync_statement!(statement)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The original transaction is preserved for audit but this financial conversion is not automatically reversible"
  end

  private

  def resync_statement!(statement)
    total = MigrationTransaction
            .where(card_id: CARD_ID, archived_at: nil, billing_statement: PERIOD_START..PERIOD_END)
            .sum(Arel.sql("CASE WHEN refund THEN -value ELSE value END"))
    paid = MigrationCardStatementPayment.where(card_statement_id: statement.id).sum(:amount)
    remaining = [total.to_d - paid.to_d, 0.to_d].max
    paid_at = remaining.zero? && total.to_d.positive? ? MigrationCardStatementPayment.where(card_statement_id: statement.id).maximum(:paid_at) : nil

    statement.update_columns(total_amount: total, paid_amount: paid, paid_at: paid_at, updated_at: Time.current)
    say "Nubank 07/2026 resynced: total=#{total.to_d.to_s('F')} paid=#{paid.to_d.to_s('F')} remaining=#{remaining.to_s('F')}"
  end
end
