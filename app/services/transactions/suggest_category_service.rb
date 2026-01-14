module Transactions
  class SuggestCategoryService
    Result = Struct.new(:suggested_category, :confidence, :source, keyword_init: true)

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      return nil if @transaction.category_id.present?

      merchant = Merchants::Normalize.call(@transaction.description)

      alias_record = MerchantAlias.find_by(normalized_merchant: merchant)
      return nil unless alias_record

      Result.new(
        suggested_category: alias_record.category,
        confidence: alias_record.confidence,
        source: :alias
      )
    end
  end
end