module Accounts
  class StatementBuilder
    CASH_EXPENSE_SOURCES = %w[cash bank].freeze
    DIRECTIONS = %w[credit debit].freeze
    MOVEMENT_TYPES = %w[
      initial_balance
      income
      expense
      card_statement_payment
      transfer_in
      transfer_out
    ].freeze
    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100

    Result = Struct.new(:account, :items, :all_items, :balances, :summary, :pagination, :period, :filters, keyword_init: true)

    def self.call(account:, params: {}, paginate: true)
      new(account: account, params: params, paginate: paginate).call
    end

    def initialize(account:, params: {}, paginate: true)
      @account = account
      @params = params
      @pagination_enabled = paginate
    end

    def call
      filtered_entries = apply_filters(entries)
      sorted_entries = sort_entries(filtered_entries)
      paginated_entries = paginate(sorted_entries)

      Result.new(
        account: account,
        items: paginated_entries,
        all_items: sorted_entries,
        balances: balances,
        summary: summary_for(sorted_entries),
        pagination: pagination_for(sorted_entries),
        period: period,
        filters: filters
      )
    end

    private

    attr_reader :account, :params, :pagination_enabled

    def entries
      [
        initial_balance_entry,
        income_entries,
        cash_expense_entries,
        card_statement_payment_entries,
        outgoing_transfer_entries,
        incoming_transfer_entries
      ].flatten
    end

    def initial_balance_entry
      StatementEntry.new(
        id: "initial-balance-#{account.id}",
        source_type: "account",
        source_id: account.id,
        movement_type: "initial_balance",
        direction: "credit",
        amount: account.initial_balance,
        occurred_on: account.initial_balance_date,
        title: "Saldo inicial",
        description: "Saldo informado ao criar a conta",
        created_at: account.created_at,
        metadata: {}
      )
    end

    def income_entries
      account.transactions
             .active
             .incomes
             .where(user_id: account.user_id)
             .includes(:category)
             .map do |transaction|
        transaction_entry(
          transaction,
          movement_type: "income",
          direction: "credit",
          title: transaction.description
        )
      end
    end

    def cash_expense_entries
      account.transactions
             .active
             .expenses
             .where(user_id: account.user_id)
             .where(source: CASH_EXPENSE_SOURCES)
             .includes(:category)
             .map do |transaction|
        transaction_entry(
          transaction,
          movement_type: "expense",
          direction: "debit",
          title: transaction.description
        )
      end
    end

    def transaction_entry(transaction, movement_type:, direction:, title:)
      StatementEntry.new(
        id: "transaction-#{transaction.id}",
        source_type: "transaction",
        source_id: transaction.id,
        movement_type: movement_type,
        direction: direction,
        amount: transaction.value,
        occurred_on: transaction.date,
        title: title,
        description: transaction.note,
        created_at: transaction.created_at,
        metadata: {
          category: category_metadata(transaction.category),
          source: transaction.source,
          responsible: transaction.responsible
        }
      )
    end

    def card_statement_payment_entries
      account.card_statement_payments
             .joins(card_statement: :card)
             .where(cards: { user_id: account.user_id })
             .includes(card_statement: :card)
             .map do |payment|
        statement = payment.card_statement
        card = statement.card

        StatementEntry.new(
          id: "card-statement-payment-#{payment.id}",
          source_type: "card_statement_payment",
          source_id: payment.id,
          movement_type: "card_statement_payment",
          direction: "debit",
          amount: payment.amount,
          occurred_on: payment.paid_at.to_date,
          title: "Pagamento de fatura",
          description: payment.description,
          created_at: payment.created_at,
          metadata: {
            card: {
              id: card.id,
              name: card.name
            },
            billing_statement: statement.billing_statement
          }
        )
      end
    end

    def outgoing_transfer_entries
      account.outgoing_transfers
             .completed
             .where(user_id: account.user_id)
             .includes(:to_account)
             .map do |transfer|
        StatementEntry.new(
          id: "account-transfer-#{transfer.id}-out",
          source_type: "account_transfer",
          source_id: transfer.id,
          movement_type: "transfer_out",
          direction: "debit",
          amount: transfer.amount,
          occurred_on: transfer.transferred_on,
          title: "Transferência para #{transfer.to_account.name}",
          description: transfer.description,
          created_at: transfer.created_at,
          metadata: {
            counterparty_account: account_metadata(transfer.to_account),
            note: transfer.note
          }
        )
      end
    end

    def incoming_transfer_entries
      account.incoming_transfers
             .completed
             .where(user_id: account.user_id)
             .includes(:from_account)
             .map do |transfer|
        StatementEntry.new(
          id: "account-transfer-#{transfer.id}-in",
          source_type: "account_transfer",
          source_id: transfer.id,
          movement_type: "transfer_in",
          direction: "credit",
          amount: transfer.amount,
          occurred_on: transfer.transferred_on,
          title: "Transferência de #{transfer.from_account.name}",
          description: transfer.description,
          created_at: transfer.created_at,
          metadata: {
            counterparty_account: account_metadata(transfer.from_account),
            note: transfer.note
          }
        )
      end
    end

    def apply_filters(entries)
      entries.select do |entry|
        within_period?(entry) &&
          matches_movement_type?(entry) &&
          matches_direction?(entry)
      end
    end

    def within_period?(entry)
      return false if start_date.present? && entry.occurred_on < start_date
      return false if end_date.present? && entry.occurred_on > end_date

      true
    end

    def matches_movement_type?(entry)
      movement_type.blank? || entry.movement_type == movement_type
    end

    def matches_direction?(entry)
      direction.blank? || entry.direction == direction
    end

    def sort_entries(entries)
      entries.sort_by do |entry|
        [
          -entry.occurred_on.jd,
          -entry.created_at.to_i,
          entry.source_type,
          -entry.source_id.to_i,
          entry.direction
        ]
      end
    end

    def paginate(entries)
      return entries unless pagination_enabled

      entries.slice((page - 1) * per_page, per_page) || []
    end

    def summary_for(entries)
      credits_total = entries.select(&:credit?).sum(0.to_d, &:amount)
      debits_total = entries.select(&:debit?).sum(0.to_d, &:amount)

      {
        credits_total: credits_total,
        debits_total: debits_total,
        net_total: credits_total - debits_total
      }
    end

    def pagination_for(entries)
      total_count = entries.size
      total_pages = (total_count.to_f / per_page).ceil

      {
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages
      }
    end

    def balances
      {
        opening_balance: opening_balance,
        closing_balance: closing_balance
      }
    end

    def opening_balance
      return 0.to_d if start_date.blank?

      Accounts::BalanceAtDateCalculator.call(account: account, as_of: start_date - 1.day)
    end

    def closing_balance
      Accounts::BalanceAtDateCalculator.call(
        account: account,
        as_of: end_date || Accounts::BalanceAtDateCalculator::ALL_KNOWN_EVENTS_CUTOFF
      )
    end

    def period
      {
        start_date: start_date,
        end_date: end_date
      }
    end

    def filters
      {
        movement_type: movement_type,
        direction: direction
      }
    end

    def start_date
      @start_date ||= parse_date_param(:start_date)
    end

    def end_date
      @end_date ||= parse_date_param(:end_date)
    end

    def movement_type
      @movement_type ||= begin
        value = params[:movement_type].presence
        raise ArgumentError, "Tipo de movimento inválido." if value.present? && !MOVEMENT_TYPES.include?(value)

        value
      end
    end

    def direction
      @direction ||= begin
        value = params[:direction].presence
        raise ArgumentError, "Direção inválida." if value.present? && !DIRECTIONS.include?(value)

        value
      end
    end

    def page
      @page ||= [(params[:page].presence || 1).to_i, 1].max
    end

    def per_page
      @per_page ||= begin
        requested = (params[:per_page].presence || DEFAULT_PER_PAGE).to_i
        requested = DEFAULT_PER_PAGE if requested <= 0
        [requested, MAX_PER_PAGE].min
      end
    end

    def parse_date_param(param_name)
      value = params[param_name].presence
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      raise ArgumentError, "Data inválida para #{param_name}."
    end

    def category_metadata(category)
      return nil if category.blank?

      {
        id: category.id,
        name: category.name
      }
    end

    def account_metadata(account)
      {
        id: account.id,
        name: account.name
      }
    end
  end
end
