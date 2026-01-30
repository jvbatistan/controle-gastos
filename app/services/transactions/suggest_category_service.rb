module Transactions
  class SuggestCategoryService
    Result = Struct.new(:suggested_category, :confidence, :source, keyword_init: true)

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      return nil if @transaction.category_id.present?

      merchant = Merchants::Canonicalize.call(@transaction.description)
      merchant = "UBER EATS" if uber_eats?(@transaction.description)
      merchant = "UBER"      if uber_trip?(@transaction.description)

      alias_record ||= find_alias_in_merchant_string(merchant)

      if alias_record
        return Result.new(
          suggested_category: alias_record.category,
          confidence: alias_record.confidence,
          source: :alias
        )
      end

      fallback = fallback_category_for(@transaction.description)
      return nil unless fallback

      Result.new(
        suggested_category: fallback,
        confidence: 0.6,
        source: :rule
      )
    end

    private 

    def uber_eats?(description)
      d = description.to_s.upcase
      d.include?("UBER") && (d.include?("EATS") || d.include?("UBER EATS"))
    end

    def uber_trip?(description)
      d = description.to_s.upcase
      d.include?("UBER") && !d.include?("EATS")
    end

    def fallback_category_for(description)
      d = description.to_s.upcase

      if d.include?("POSTO") || d.include?("SHELL") || d.include?("IPIRANGA") || d.include?("PETROBRAS") || d.include?("ALE")
        return Category.find_by(name: "Transporte")
      end

      if d.include?("IFOOD")
        return Category.find_by(name: "Alimentação")
      end

      if d.include?("UBER") && (d.include?("EATS") || d.include?("UBER EATS"))
        return Category.find_by(name: "Alimentação")
      end

      if d.include?("UBER")
        return Category.find_by(name: "Transporte")
      end

      nil
    end

    def find_alias_in_merchant_string(merchant)
      return nil if merchant.blank?

      parts = merchant.to_s.upcase.split(/\s+/)

      candidates = []
      candidates << parts.join(" ") if parts.size > 1
      candidates.concat(parts.reverse)

      candidates.each do |candidate|
        found = MerchantAlias.find_by(normalized_merchant: candidate)
        return found if found
      end

      nil
    end
  end
end