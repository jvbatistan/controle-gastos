class DebtStatementService
  def initialize(debt)
    @debt = debt
    @card = debt.card
  end

  def call
    return unless @card.present? && @debt.transaction_date.present?

    month = @debt.transaction_date.month
    year  = @debt.transaction_date.year

    # Calcula a data de fechamento e vencimento
    closing_date = Date.new(year, month, @card.due_date) - @card.closing_date

    if @debt.transaction_date >= closing_date
      due_date = closing_date + 1.month + @card.closing_date
    else
      due_date = closing_date + @card.closing_date
    end

    @debt.billing_statement = due_date
  end
end
