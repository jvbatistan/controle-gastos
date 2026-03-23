module Transactions
  class CreateCategorySuggestionService
    def initialize(transaction, force_recompute: false)
      @transaction = transaction
      @user = transaction.user
      @force_recompute = force_recompute
    end

    def call
      return nil if @transaction.category_id.present?

      clear_pending_suggestions! if @force_recompute

      existing = @transaction.classification_suggestions.pending.order(created_at: :desc).first
      return existing if existing

      group_existing = pending_for_installment_group
      return group_existing if group_existing

      result = Transactions::SuggestCategoryService.new(@transaction).call

      if result&.suggested_category.present? && result.confidence.to_f >= 0.95
        @transaction.update!(category_id: result.suggested_category.id)
        return nil
      end

      ClassificationSuggestion.create!(
        user: @user,
        financial_transaction_id: @transaction.id,
        suggested_category: result&.suggested_category,
        confidence: result&.confidence || 0.0,
        source: ClassificationSuggestion.sources[result&.source || :rule]
      )
    end

    private

    def clear_pending_suggestions!
      scope = ClassificationSuggestion.pending.where(financial_transaction_id: suggestion_target_ids)
      scope.delete_all
    end

    def pending_for_installment_group
      gid = @transaction.installment_group_id
      return nil if gid.blank?

      ClassificationSuggestion.where(financial_transaction_id: suggestion_target_ids).pending.order(created_at: :desc).first
    end

    def suggestion_target_ids
      return [@transaction.id] if @transaction.installment_group_id.blank?

      Transaction.where(installment_group_id: @transaction.installment_group_id).pluck(:id)
    end
  end
end
