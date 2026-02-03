module Transactions
  class CreateCategorySuggestionService
    def initialize(transaction)
      @transaction = transaction
    end

    def call
      return nil if @transaction.category_id.present?

      existing = @transaction.classification_suggestions.pending.first
      return existing if existing

      group_existing = pending_for_installment_group
      return group_existing if group_existing

      result = Transactions::SuggestCategoryService.new(@transaction).call

      if (result.nil? || result.suggested_category.nil?) || result&.confidence.to_f < 0.95
        return ClassificationSuggestion.create!(
          financial_transaction_id: @transaction.id,
          suggested_category: result&.suggested_category,
          confidence: result&.confidence || 0.0,
          source: ClassificationSuggestion.sources[result&.source || :rule]
        )
      end

      if result.confidence.to_f >= 0.95
        @transaction.update!(category_id: result.suggested_category.id)
        return nil
      end
    end

    private
    def pending_for_installment_group
      gid = @transaction.installment_group_id
      return nil if gid.blank?

      tx_ids = Transaction.where(installment_group_id: gid).pluck(:id)

       ClassificationSuggestion.where(financial_transaction_id: tx_ids).pending.first
    end
  end
end