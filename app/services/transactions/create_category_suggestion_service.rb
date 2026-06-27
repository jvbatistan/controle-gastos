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

      suggested_category = owned_category(result&.suggested_category)

      if suggested_category.present? && result.confidence.to_f >= 0.95
        apply_category(suggested_category)
        clear_pending_suggestions!
        return nil
      end

      ClassificationSuggestion.create!(
        user: @user,
        financial_transaction_id: @transaction.id,
        suggested_category: suggested_category,
        confidence: result&.confidence || 0.0,
        source: ClassificationSuggestion.sources[result&.source || :rule]
      )
    end

    private

    def apply_category(category)
      if @transaction.installment_group_id.present?
        Transactions::ApplyCategoryToInstallmentGroupService.new(
          transaction: @transaction,
          category: category
        ).call
      else
        @transaction.update!(category: category)
      end
    end

    def clear_pending_suggestions!
      scope = @user.classification_suggestions.pending.where(financial_transaction_id: suggestion_target_ids)
      scope.delete_all
    end

    def pending_for_installment_group
      gid = @transaction.installment_group_id
      return nil if gid.blank?

      @user.classification_suggestions
           .where(financial_transaction_id: suggestion_target_ids)
           .pending
           .order(created_at: :desc)
           .first
    end

    def suggestion_target_ids
      return [@transaction.id] if @transaction.installment_group_id.blank?

      @user.transactions.where(installment_group_id: @transaction.installment_group_id).pluck(:id)
    end

    def owned_category(category)
      return nil if category.nil?

      @user.categories.find(category.id)
    end
  end
end
