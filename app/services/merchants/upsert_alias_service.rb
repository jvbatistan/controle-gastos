module Merchants
  class UpsertAliasService
    def initialize(description:, category_id:, confidence: 0.95, source: :user_override)
      @description = description
      @category_id = category_id
      @confidence  = confidence.to_f
      @source      = source
    end

    def call
      normalized = Merchants::Normalize.call(@description)

      MerchantAlias.find_or_initialize_by(normalized_merchant: normalized).tap do |alias_record|
        alias_record.category_id = @category_id
        alias_record.confidence  = [@confidence, 0.95].max
        alias_record.source      = @source
        alias_record.save!
      end
    end
  end
end
