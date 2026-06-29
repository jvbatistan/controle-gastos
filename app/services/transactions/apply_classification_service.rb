module Transactions
  class ApplyClassificationService
    def self.call(suggestion:, category:, learn: true, mark_as:, alias_confidence: nil)
      new(
        suggestion: suggestion,
        category: category,
        learn: learn,
        mark_as: mark_as,
        alias_confidence: alias_confidence
      ).call
    end

    def initialize(suggestion:, category:, learn: true, mark_as:, alias_confidence: nil)
      @suggestion = suggestion
      @transaction = suggestion.financial_transaction
      @category = category
      @learn = learn
      @mark_as = mark_as
      @alias_confidence = alias_confidence
    end

    def call
      category = owned_category

      Transaction.transaction do
        @transaction.update!(category: category)
        resolve_suggestion!
        propagate_to_installment_group!(category)
        learn_alias!(category) if @learn
      end

      @suggestion
    end

    private

    def owned_category
      @transaction.user.categories.find(@category.id)
    end

    def resolve_suggestion!
      timestamp = Time.current

      case @mark_as
      when :accepted
        @suggestion.update!(accepted_at: timestamp)
      when :rejected
        @suggestion.update!(rejected_at: timestamp)
      else
        raise ArgumentError, "mark_as must be :accepted or :rejected"
      end
    end

    def propagate_to_installment_group!(category)
      gid = @transaction.installment_group_id
      return 0 if gid.blank?

      Transactions::ApplyCategoryToInstallmentGroupService.new(
        transaction: @transaction,
        category: category
      ).call

      tx_ids = @transaction.user.transactions.where(installment_group_id: gid).pluck(:id)
      scope = @transaction.user.classification_suggestions.pending.where(financial_transaction_id: tx_ids)
      now = Time.current

      if @mark_as == :accepted
        scope.update_all(accepted_at: now, updated_at: now)
      else
        scope.update_all(rejected_at: now, updated_at: now)
      end
    end

    def learn_alias!(category)
      Merchants::UpsertAliasService.new(
        user: @transaction.user,
        description: @transaction.description,
        category: category,
        confidence: @alias_confidence || 1.0,
        source: :user_override
      ).call
    end
  end
end
