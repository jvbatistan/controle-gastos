class BillingStatementService
  def initialize(transaction)
    @transaction = transaction
    @card = transaction.card
  end

  def call
    return unless @card.present? && @transaction.date.present?

    reference_date = @transaction.date.to_date
    closing_date = @card.closing_on(reference_date.year, reference_date.month)

    statement_date =
      if reference_date >= closing_date
        reference_date.next_month
      else
        reference_date
      end

    @transaction.billing_statement = Date.new(statement_date.year, statement_date.month, 1)
  end
end
