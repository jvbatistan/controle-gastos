class Api::DashboardController < Api::BaseController
  before_action :authenticate_user!

  def show
    render json: {
      period: {
        month: selected_month,
        year: selected_year,
        label: I18n.l(period_start, format: "%B/%Y")
      },
      summary: {
        expenses_total: period_expenses.sum(:value),
        open_total: period_expenses.where(paid: false).sum(:value),
        paid_total: period_expenses.where(paid: true).sum(:value),
        transactions_count: period_expenses.count
      },
      by_card: totals_by_card,
      by_category: totals_by_category,
      recent_expenses: recent_expenses,
      statements: statement_overview
    }
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

  def base_expenses_scope
    current_user.transactions.active.expenses.includes(:category, :card)
  end

  def period_expenses
    @period_expenses ||= base_expenses_scope.where(
      "(card_id IS NOT NULL AND billing_statement BETWEEN ? AND ?) OR (card_id IS NULL AND date BETWEEN ? AND ?)",
      period_start,
      period_end,
      period_start,
      period_end
    )
  end

  def totals_by_card
    grouped = period_expenses.to_a.group_by { |transaction| transaction.card }

    grouped.map do |card, transactions|
      {
        id: card&.id,
        name: card&.name || "Sem cartão",
        total_amount: transactions.sum { |transaction| transaction.value.to_d },
        open_amount: transactions.reject(&:paid).sum { |transaction| transaction.value.to_d },
        paid_amount: transactions.select(&:paid).sum { |transaction| transaction.value.to_d },
        transactions_count: transactions.size
      }
    end.sort_by { |entry| [-entry[:total_amount].to_d, entry[:name].to_s] }
  end

  def totals_by_category
    grouped = period_expenses.to_a.group_by { |transaction| transaction.category }

    grouped.map do |category, transactions|
      {
        id: category&.id,
        name: category&.name || "Sem categoria",
        total_amount: transactions.sum { |transaction| transaction.value.to_d },
        transactions_count: transactions.size
      }
    end.sort_by { |entry| [-entry[:total_amount].to_d, entry[:name].to_s] }
  end

  def recent_expenses
    base_expenses_scope.order(created_at: :desc, id: :desc).limit(8).map do |transaction|
      {
        id: transaction.id,
        description: transaction.description,
        value: transaction.value,
        date: transaction.date,
        paid: transaction.paid,
        card: transaction.card&.as_json(only: %i[id name]),
        category: transaction.category&.as_json(only: %i[id name]),
        installment_number: transaction.installment_number,
        installments_count: transaction.installments_count
      }
    end
  end

  def statement_overview
    current_user.cards.ordenados.filter_map do |card|
      statement = card.sync_statement!(selected_month, selected_year)
      next if statement.ignored? || statement.total_amount.to_d <= 0

      {
        id: statement.id,
        card: {
          id: card.id,
          name: card.name
        },
        billing_statement: statement.billing_statement,
        total_amount: statement.total_amount,
        paid_amount: statement.paid_amount,
        remaining_amount: statement.remaining_amount,
        paid: statement.paid?,
        due_day: card.due_day_value,
        closing_day: card.closing_day_value(statement.billing_statement),
        transactions_count: card.transactions
                                .active
                                .where(billing_statement: statement.billing_statement.beginning_of_month..statement.billing_statement.end_of_month)
                                .count
      }
    end
  end
end
