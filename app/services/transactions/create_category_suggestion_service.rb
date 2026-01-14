module Transactions
  class CreateCategorySuggestionService
    def initialize(transaction)
      @transaction = transaction
    end

    def call
      result = Transactions::SuggestCategoryService.new(@transaction).call
      return nil unless result

      existing = @transaction.classification_suggestions.pending.first
      return existing if existing

      ClassificationSuggestion.create!(
        financial_transaction_id: @transaction.id,
        suggested_category: result.suggested_category,
        confidence: result.confidence,
        source: ClassificationSuggestion.sources[result.source]
      )
    end
  end
end