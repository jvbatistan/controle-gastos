class ClassificationSuggestionsController < ApplicationController
  def index
    @suggestions = ClassificationSuggestion
      .pending
      .includes(:financial_transaction, :suggested_category)
      .order(created_at: :desc)
  end

  def accept
    suggestion = ClassificationSuggestion.find(params[:id])

    Transaction.transaction do
      suggestion.financial_transaction.update!(category_id: suggestion.suggested_category_id)
      suggestion.update!(accepted_at: Time.current)

      Merchants::UpsertAliasService.new(
        description: suggestion.financial_transaction.description,
        category_id: suggestion.suggested_category_id,
        confidence: suggestion.confidence,
        source: :user_override
      ).call
    end

    redirect_to classification_suggestions_path, notice: "Sugestão aplicada."
  end

  def reject
    suggestion = ClassificationSuggestion.find(params[:id])
    suggestion.update!(rejected_at: Time.current)

    redirect_to classification_suggestions_path, notice: "Sugestão recusada."
  end
end
