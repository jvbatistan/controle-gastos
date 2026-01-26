module Transactions
  class CreateCategorySuggestionService
    def initialize(transaction)
      @transaction = transaction
    end

    def call
      existing = @transaction.classification_suggestions.pending.first
      return existing if existing

      result = Transactions::SuggestCategoryService.new(@transaction).call

      ClassificationSuggestion.create!(
        financial_transaction_id: @transaction.id,
        suggested_category: result&.suggested_category,
        confidence: result&.confidence || 0.0,
        source: ClassificationSuggestion.sources[result&.source || :rule]
      )
    end
  end
end