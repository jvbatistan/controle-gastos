class RepairNubankJuly2026Statement < ActiveRecord::Migration[6.1]
  class MigrationCard < ActiveRecord::Base
    self.table_name = "cards"
  end

  class MigrationTransaction < ActiveRecord::Base
    self.table_name = "transactions"
  end

  class MigrationCardStatement < ActiveRecord::Base
    self.table_name = "card_statements"
  end

  class MigrationCardStatementPayment < ActiveRecord::Base
    self.table_name = "card_statement_payments"
  end

  CARD_ID = 2
  PERIOD_START = Date.new(2026, 7, 1)
  PERIOD_END = PERIOD_START.end_of_month

  MISSING_PURCHASES = [
    { date: Date.new(2026, 6, 8), value: "6.92" },
    { date: Date.new(2026, 6, 8), value: "6.72" },
    { date: Date.new(2026, 6, 12), value: "6.91" }
  ].freeze

  CENT_CORRECTIONS = [
    { id: 642, description: "IOF DE COMPRA INTERNACIONAL", from: "0.94", to: "0.93" },
    { id: 33, description: "ZP *FBIO LOPES", from: "58.91", to: "58.86" }
  ].freeze

  def up
    card = MigrationCard.find_by(id: CARD_ID)
    return say("Skipping Nubank 07/2026 repair: card ##{CARD_ID} was not found") if card.nil?
    return say("Skipping Nubank 07/2026 repair: card ##{CARD_ID} is #{card.name}, not NUBANK") unless card.name.to_s.upcase == "NUBANK"

    correct_cents!
    restore_missing_purchases!(card)
    resync_statement!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "This migration repairs audited financial data"
  end

  private

  def correct_cents!
    CENT_CORRECTIONS.each do |correction|
      transaction = MigrationTransaction.find_by(
        id: correction[:id],
        card_id: CARD_ID,
        description: correction[:description],
        value: BigDecimal(correction[:from])
      )

      if transaction
        say "Correcting transaction ##{transaction.id}: #{correction[:from]} -> #{correction[:to]}"
        transaction.update_columns(value: BigDecimal(correction[:to]), updated_at: Time.current)
      else
        say "Skipping cent correction for transaction ##{correction[:id]}: audited values no longer match"
      end
    end
  end

  def restore_missing_purchases!(card)
    MISSING_PURCHASES.each do |entry|
      attributes = {
        card_id: card.id,
        user_id: card.user_id,
        description: "UBER - NUPAY",
        value: BigDecimal(entry[:value]),
        date: entry[:date],
        kind: 1,
        source: 0,
        refund: false,
        paid: false,
        billing_statement: PERIOD_START,
        archived_at: nil
      }

      existing = MigrationTransaction.find_by(attributes)
      if existing
        say "Skipping missing purchase #{entry[:date]} #{entry[:value]}: transaction ##{existing.id} already exists"
        next
      end

      refund = MigrationTransaction.find_by(
        card_id: card.id,
        date: entry[:date],
        description: "UBER - NUPAY",
        value: BigDecimal(entry[:value]),
        refund: true,
        billing_statement: PERIOD_START
      )

      say "Restoring missing Uber purchase: #{entry[:date]} #{entry[:value]}"
      MigrationTransaction.create!(
        attributes.merge(
          category_id: refund&.category_id,
          created_at: Time.current,
          updated_at: Time.current
        )
      )
    end
  end

  def resync_statement!
    statement = MigrationCardStatement.where(card_id: CARD_ID, billing_statement: PERIOD_START..PERIOD_END).first
    return say("Skipping statement resync: Nubank statement 07/2026 was not found") if statement.nil?

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
