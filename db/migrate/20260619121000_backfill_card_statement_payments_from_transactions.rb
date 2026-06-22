class BackfillCardStatementPaymentsFromTransactions < ActiveRecord::Migration[6.1]
  class MigrationCard < ActiveRecord::Base
    self.table_name = "cards"

    has_many :card_statements, class_name: "BackfillCardStatementPaymentsFromTransactions::MigrationCardStatement", foreign_key: :card_id

    def due_on(year, month)
      day = due_day.presence || due_date
      Date.new(year.to_i, month.to_i, [day.to_i, Date.civil(year.to_i, month.to_i, -1).day].min)
    end
  end

  class MigrationCardStatement < ActiveRecord::Base
    self.table_name = "card_statements"

    belongs_to :card, class_name: "BackfillCardStatementPaymentsFromTransactions::MigrationCard"
  end

  class MigrationTransaction < ActiveRecord::Base
    self.table_name = "transactions"

    belongs_to :card, class_name: "BackfillCardStatementPaymentsFromTransactions::MigrationCard", optional: true
  end

  class MigrationCardStatementPayment < ActiveRecord::Base
    self.table_name = "card_statement_payments"
  end

  PAYMENT_PATTERN = /(^PAGAMENTO$|PAGAMENTO\s+RECEBIDO|PAGAMENTO\s+(PRA|PARA)\s+LIBERAR\s+LIMITE|LIBERAR\s+LIMITE|PGTO\s+RECEBIDO|PAGTO\s+RECEBIDO)/i
  MERCHANT_EXCLUSION_PATTERN = /(UBER|99|NUPAY|APPLE|TWITCH|SPOTIFY)/i

  def up
    say_with_time "Converting clear card statement payment transactions" do
      converted_count = 0

      candidate_scope.find_each do |transaction|
        statement = statement_for(transaction)
        next if statement.nil?

        paid_at = transaction.date.to_time.in_time_zone
        description = transaction.description.to_s
        source = "converted_transaction"

        say "Converting transaction ##{transaction.id}: #{description} | #{transaction.value} | #{transaction.date}"

        payment = MigrationCardStatementPayment.find_or_initialize_by(original_transaction_id: transaction.id)
        payment.card_statement_id = statement.id
        payment.amount = transaction.value.to_d.abs
        payment.paid_at = paid_at
        payment.description = description
        payment.source = source
        payment.save!

        transaction.update_columns(
          archived_at: transaction.archived_at || Time.current,
          payment_ignored_at: transaction.payment_ignored_at || Time.current,
          updated_at: Time.current
        )
        converted_count += 1
      end

      resync_statements!
      converted_count
    end
  end

  def down
    payment_scope.find_each do |payment|
      MigrationTransaction.where(id: payment.original_transaction_id).update_all(
        archived_at: nil,
        payment_ignored_at: nil,
        updated_at: Time.current
      )
      payment.destroy!
    end

    resync_statements!
  end

  private

  def candidate_scope
    MigrationTransaction
      .where.not(card_id: nil)
      .where(archived_at: nil)
      .where(refund: false)
      .where("description ~* ?", PAYMENT_PATTERN.source)
      .where.not("description ~* ?", MERCHANT_EXCLUSION_PATTERN.source)
  end

  def payment_scope
    MigrationCardStatementPayment.where(source: "converted_transaction").where.not(original_transaction_id: nil)
  end

  def statement_for(transaction)
    card = transaction.card
    return nil if card.nil?

    reference = transaction.billing_statement || transaction.date
    billing_statement = card.due_on(reference.year, reference.month)
    MigrationCardStatement.find_or_create_by!(card_id: card.id, billing_statement: billing_statement)
  end

  def resync_statements!
    MigrationCardStatement.find_each do |statement|
      start_date = statement.billing_statement.beginning_of_month
      end_date = statement.billing_statement.end_of_month
      total = MigrationTransaction
              .where(card_id: statement.card_id, archived_at: nil)
              .where(billing_statement: start_date..end_date)
              .sum(Arel.sql("CASE WHEN refund THEN -value ELSE value END"))
      paid = MigrationCardStatementPayment.where(card_statement_id: statement.id).sum(:amount)
      paid_at = paid.to_d >= total.to_d && total.to_d.positive? ? MigrationCardStatementPayment.where(card_statement_id: statement.id).maximum(:paid_at) : nil

      statement.update_columns(total_amount: total, paid_amount: paid, paid_at: paid_at, updated_at: Time.current)
    end
  end
end
