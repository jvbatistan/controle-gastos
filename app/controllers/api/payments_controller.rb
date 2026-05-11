class Api::PaymentsController < Api::BaseController
  before_action :authenticate_user!

  def index
    period_statements = current_user.cards.ordenados.map { |card| card.sync_statement!(selected_month, selected_year) }
    statements = period_statements.reject(&:ignored?).map { |statement| payment_statement_json(statement) }
    ignored_statements = period_statements.select(&:ignored?).map { |statement| payment_statement_json(statement) }
    loose_scope = loose_expenses_scope
    loose_total = loose_scope.sum(:value)
    ignored_loose_scope = ignored_loose_expenses_scope
    ignored_loose_total = ignored_loose_scope.sum(:value)

    render json: {
      period: {
        month: selected_month,
        year: selected_year
      },
      statements: statements,
      loose_expenses: {
        period_label: I18n.l(period_start, format: '%m/%Y'),
        transactions_count: loose_scope.count,
        total_amount: loose_total,
        paid: loose_scope.none?,
        transactions: loose_scope.order(date: :desc, value: :desc).limit(50).map { |transaction| loose_transaction_json(transaction) }
      },
      ignored_payments: {
        period_label: I18n.l(period_start, format: '%m/%Y'),
        statements_count: ignored_statements.count,
        statements_total_amount: ignored_statements.sum { |statement| statement[:remaining_amount].to_d },
        statements: ignored_statements,
        loose_expenses: {
          transactions_count: ignored_loose_scope.count,
          total_amount: ignored_loose_total,
          transactions: ignored_loose_scope.order(payment_ignored_at: :desc, date: :desc, value: :desc).limit(50).map { |transaction| loose_transaction_json(transaction) }
        }
      }
    }
  end

  def pay_card_statement
    statement = current_user_card_statements.active_for_payments.find(params[:id])
    amount = payment_amount_param(statement.remaining_amount)

    statement.apply_payment!(amount)
    statement.card.sync_statement!(statement.billing_statement.month, statement.billing_statement.year)

    render json: payment_statement_json(statement.reload), status: :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def pay_loose_expenses
    scope = loose_expenses_scope
    count = scope.count
    total = scope.sum(:value)

    scope.update_all(paid: true, updated_at: Time.current)

    render json: {
      period: {
        month: selected_month,
        year: selected_year
      },
      paid_transactions_count: count,
      total_amount: total
    }, status: :ok
  end

  def ignore_card_statement
    statement = current_user_card_statements.active_for_payments.where(billing_statement: period_start..period_end).find(params[:id])
    statement.ignore_for_payment!

    render json: payment_statement_json(statement.reload), status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Fatura não encontrada para o período selecionado." }, status: :not_found
  end

  def pay_loose_expense
    transaction = loose_expenses_scope.find(params[:id])
    transaction.update!(paid: true)

    render json: loose_transaction_json(transaction.reload), status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Despesa avulsa não encontrada para o período selecionado." }, status: :not_found
  end

  def ignore_loose_expense
    transaction = loose_expenses_scope.find(params[:id])
    transaction.ignore_for_payment!

    render json: loose_transaction_json(transaction.reload), status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Despesa avulsa não encontrada para o período selecionado." }, status: :not_found
  end

  private

  def selected_month
    @selected_month ||= begin
      month = params[:month].to_i
      month.between?(1, 12) ? month : Date.current.month
    end
  end

  def selected_year
    @selected_year ||= begin
      year = params[:year].to_i
      year.positive? ? year : Date.current.year
    end
  end

  def period_start
    @period_start ||= Date.new(selected_year, selected_month, 1)
  end

  def period_end
    @period_end ||= period_start.end_of_month
  end

  def loose_expenses_scope
    current_user.transactions
                .active
                .active_for_payments
                .expenses
                .where(card_id: nil, paid: false)
                .where(date: period_start..period_end)
  end

  def ignored_loose_expenses_scope
    current_user.transactions
                .active
                .expenses
                .where(card_id: nil, paid: false)
                .where(date: period_start..period_end)
                .where.not(payment_ignored_at: nil)
  end

  def current_user_card_statements
    CardStatement.joins(:card).where(cards: { user_id: current_user.id })
  end


  def payment_amount_param(default_amount)
    value = params[:amount].presence || params.dig(:payment, :amount).presence
    return default_amount if value.blank?

    parsed = value.to_s.tr(',', '.').to_d
    raise ArgumentError, 'Pagamento deve ser > 0' if parsed <= 0

    parsed
  end

  def payment_statement_json(statement)
    {
      id: statement.id,
      card: {
        id: statement.card.id,
        name: statement.card.name
      },
      billing_statement: statement.billing_statement,
      total_amount: statement.total_amount,
      paid_amount: statement.paid_amount,
      remaining_amount: statement.remaining_amount,
      paid: statement.paid?,
      paid_at: statement.paid_at,
      ignored_at: statement.ignored_at,
      due_day: statement.card.due_day_value,
      closing_day: statement.card.closing_day_value(statement.billing_statement),
      transactions_count: statement.card.transactions
                                .active
                                .where(billing_statement: statement.billing_statement.beginning_of_month..statement.billing_statement.end_of_month)
                                .count
    }
  end

  def loose_transaction_json(transaction)
    {
      id: transaction.id,
      description: transaction.description,
      value: transaction.value,
      date: transaction.date,
      source: transaction.source,
      category_id: transaction.category_id,
      paid: transaction.paid,
      payment_ignored_at: transaction.payment_ignored_at,
      installment_number: transaction.installment_number,
      installments_count: transaction.installments_count,
      note: transaction.note,
    }
  end
end
