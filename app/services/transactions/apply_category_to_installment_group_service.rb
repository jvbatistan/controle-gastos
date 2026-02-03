module Transactions
  class ApplyCategoryToInstallmentGroupService
    def initialize(transaction:, category_id:)
      @transaction = transaction
      @category_id = category_id
    end

    def call
      gid = @transaction.installment_group_id
      return 0 if gid.blank?

      Transaction.transaction do
        Transaction.where(installment_group_id: gid).update_all(category_id: @category_id, updated_at: Time.current)
      end
    end
  end
end
