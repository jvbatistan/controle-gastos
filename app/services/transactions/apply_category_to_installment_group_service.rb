module Transactions
  class ApplyCategoryToInstallmentGroupService
    def initialize(transaction:, category:)
      @transaction = transaction
      @category = category
    end

    def call
      category_id = owned_category&.id
      gid = @transaction.installment_group_id
      return 0 if gid.blank?

      Transaction.transaction do
        @transaction.user.transactions
                    .where(installment_group_id: gid)
                    .update_all(category_id: category_id, updated_at: Time.current)
      end
    end

    private

    def owned_category
      return nil if @category.nil?

      @transaction.user.categories.find(@category.id)
    end
  end
end
