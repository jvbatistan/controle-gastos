module Transactions
  class SuggestCategoryService
    Result = Transactions::ClassificationResult

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      Transactions::ClassificationEngine.call(@transaction)
    end
  end
end
