module CardStatements
  class PeriodSnapshot
    Result = Struct.new(:cards, :statements, :transaction_counts, keyword_init: true)

    def initialize(user:, month:, year:)
      @user = user
      @month = month.to_i
      @year = year.to_i
    end

    def call
      cards = user.cards.ordenados.to_a
      return Result.new(cards: [], statements: [], transaction_counts: {}) if cards.empty?

      billing_dates = cards.index_with { |card| card.due_on(year, month) }
      statements = load_statements(cards, billing_dates)
      totals, transaction_counts = transaction_aggregates(cards)
      payment_totals, latest_payments = payment_aggregates(statements)

      statements.each do |statement|
        statement.sync_totals!(
          total_amount: totals.fetch(statement.card_id, 0.to_d),
          paid_amount: payment_totals.fetch(statement.id, 0.to_d),
          latest_paid_at: latest_payments[statement.id]
        )
      end

      Result.new(cards: cards, statements: statements, transaction_counts: transaction_counts)
    end

    private

    attr_reader :user, :month, :year

    def period_start
      @period_start ||= Date.new(year, month, 1)
    end

    def period_end
      @period_end ||= period_start.end_of_month
    end

    def load_statements(cards, billing_dates)
      existing = CardStatement
                 .where(card_id: cards.map(&:id), billing_statement: billing_dates.values)
                 .index_by { |statement| [statement.card_id, statement.billing_statement] }

      cards.map do |card|
        billing_date = billing_dates.fetch(card)
        statement = existing[[card.id, billing_date]] || card.card_statements.find_or_create_by!(billing_statement: billing_date)
        statement.association(:card).target = card
        statement
      end
    end

    def transaction_aggregates(cards)
      rows = user.transactions
                 .active
                 .where(card_id: cards.map(&:id), billing_statement: period_start..period_end)
                 .group(:card_id)
                 .pluck(
                   :card_id,
                   Arel.sql("COALESCE(SUM(#{Transaction.signed_value_sql}), 0)"),
                   Arel.sql("COUNT(*)")
                 )

      totals = {}
      counts = {}
      rows.each do |card_id, total, count|
        totals[card_id] = total.to_d
        counts[card_id] = count
      end

      [totals, counts]
    end

    def payment_aggregates(statements)
      rows = CardStatementPayment
             .where(card_statement_id: statements.map(&:id))
             .group(:card_statement_id)
             .pluck(:card_statement_id, Arel.sql("COALESCE(SUM(amount), 0)"), Arel.sql("MAX(paid_at)"))

      totals = {}
      latest = {}
      rows.each do |statement_id, total, latest_paid_at|
        totals[statement_id] = total.to_d
        latest[statement_id] = latest_paid_at
      end

      [totals, latest]
    end
  end
end
