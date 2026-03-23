module Transactions
  class ClassifyService
    def initialize(transaction, force_recompute: false)
      @transaction = transaction
      @force_recompute = force_recompute
    end

    def call
      return @transaction unless @transaction.persisted?
      return @transaction if @transaction.destroyed?
      return @transaction if @transaction.category_id.present?

      Transactions::CreateCategorySuggestionService.new(
        @transaction,
        force_recompute: @force_recompute
      ).call

      @transaction.reload
    end
  end
end
