module Accounts
  class BalanceCalculator
    CASH_EXPENSE_SOURCES = %i[cash bank].freeze

    def self.call(account)
      new([account]).balances.fetch(account.id, account.initial_balance.to_d)
    end

    def self.for(accounts)
      new(accounts).balances
    end

    def initialize(accounts)
      @accounts = Array(accounts)
    end

    def balances
      @balances ||= calculate_balances
    end

    private

    attr_reader :accounts

    def calculate_balances
      ids = account_ids
      return {} if ids.empty?

      balances = accounts.each_with_object({}) do |account, result|
        result[account.id] = account.initial_balance.to_d
      end

      add_grouped_amounts(balances, income_totals)
      subtract_grouped_amounts(balances, cash_expense_totals)
      subtract_grouped_amounts(balances, card_statement_payment_totals)
      subtract_grouped_amounts(balances, outgoing_transfer_totals)
      add_grouped_amounts(balances, incoming_transfer_totals)

      balances
    end

    def account_ids
      @account_ids ||= accounts.map(&:id).compact
    end

    def income_totals
      Transaction.active
                 .incomes
                 .where(account_id: account_ids)
                 .group(:account_id)
                 .sum(Arel.sql("CASE WHEN transactions.refund THEN -COALESCE(transactions.settled_value, transactions.value) ELSE COALESCE(transactions.settled_value, transactions.value) END"))
    end

    def cash_expense_totals
      Transaction.active
                 .expenses
                 .where(account_id: account_ids, source: CASH_EXPENSE_SOURCES, paid: true)
                 .group(:account_id)
                 .sum(Arel.sql(Transaction.signed_value_sql))
    end

    def card_statement_payment_totals
      CardStatementPayment.where(account_id: account_ids)
                          .group(:account_id)
                          .sum(:amount)
    end

    def outgoing_transfer_totals
      AccountTransfer.completed
                     .where(from_account_id: account_ids)
                     .group(:from_account_id)
                     .sum(:amount)
    end

    def incoming_transfer_totals
      AccountTransfer.completed
                     .where(to_account_id: account_ids)
                     .group(:to_account_id)
                     .sum(:amount)
    end

    def add_grouped_amounts(balances, grouped_amounts)
      grouped_amounts.each do |account_id, amount|
        balances[account_id] = balances.fetch(account_id, 0.to_d) + amount.to_d
      end
    end

    def subtract_grouped_amounts(balances, grouped_amounts)
      grouped_amounts.each do |account_id, amount|
        balances[account_id] = balances.fetch(account_id, 0.to_d) - amount.to_d
      end
    end
  end
end
