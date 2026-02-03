class BillingStatementService
  def initialize(transaction)
    @transaction = transaction
    @card        = transaction.card
  end

  def call
    return unless @card.present? && @transaction.date.present?

    month = @transaction.date.month
    year  = @transaction.date.year

    reference_date = @transaction.date.to_date

    # Calcula a data de fechamento e vencimento
    closing_date = Date.new(year, month, @card.due_date) - @card.closing_date

    statement_date =
      if reference_date >= closing_date
        # due_date = closing_date + 1.month + @card.closing_date
        closing_date.next_month
      else
        # due_date = closing_date + @card.closing_date
        closing_date
      end

    @transaction.billing_statement = Date.new(statement_date.year, statement_date.month, 1)
  end
end
