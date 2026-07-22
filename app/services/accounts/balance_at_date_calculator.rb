module Accounts
  class BalanceAtDateCalculator
    CASH_EXPENSE_SOURCES = %i[cash bank].freeze
    ALL_KNOWN_EVENTS_CUTOFF = Date.new(9999, 12, 31)

    def self.call(account:, as_of:)
      new(account: account, as_of: as_of).call
    end

    def initialize(account:, as_of:)
      @account = account
      @as_of = as_of.to_date
    end

    def call
      initial_balance_amount +
        income_total -
        cash_expense_total -
        card_statement_payment_total -
        outgoing_transfer_total +
        incoming_transfer_total
    end

    private

    attr_reader :account, :as_of

    def initial_balance_amount
      return 0.to_d if account.initial_balance_date > as_of

      account.initial_balance.to_d
    end

    def income_total
      base_transactions
        .incomes
        .where(date: ..as_of)
        .sum(Arel.sql(Transaction.signed_value_sql))
        .to_d
    end

    def cash_expense_total
      base_transactions
        .expenses
        .where(source: CASH_EXPENSE_SOURCES, date: ..as_of)
        .sum(Arel.sql(Transaction.signed_value_sql))
        .to_d
    end

    def base_transactions
      Transaction.active
                 .where(account_id: account.id, user_id: account.user_id)
    end

    def card_statement_payment_total
      account.card_statement_payments
             .joins(card_statement: :card)
             .where(cards: { user_id: account.user_id })
             .where(paid_at: ..as_of.end_of_day)
             .sum(:amount)
             .to_d
    end

    def outgoing_transfer_total
      account.outgoing_transfers
             .completed
             .where(user_id: account.user_id, transferred_on: ..as_of)
             .sum(:amount)
             .to_d
    end

    def incoming_transfer_total
      account.incoming_transfers
             .completed
             .where(user_id: account.user_id, transferred_on: ..as_of)
             .sum(:amount)
             .to_d
    end
  end
end
