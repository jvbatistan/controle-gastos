class CardStatementsController < ApplicationController
  def add_payment
    statement = CardStatement.find(params[:id])

    value = params.dig(:card_statement, :paid_amount).to_d
    statement.apply_payment!(value)

    redirect_back fallback_location: totals_path, notice: "Pagamento registrado na fatura."
  rescue ArgumentError => e
    redirect_back fallback_location: totals_path, alert: e.message
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: totals_path, alert: e.record.errors.full_messages.to_sentence
  end
end
