module Transactions
  class SuggestCategoryService
    Result = Struct.new(:suggested_category, :confidence, :source, keyword_init: true)

    def initialize(transaction)
      @transaction = transaction
      @user = transaction.user
    end

    def call
      return nil if @transaction.category_id.present?

      analysis = Merchants::DescriptionAnalysis.call(@transaction.description)

      if (alias_record = find_alias(analysis))
        return result_from_alias(alias_record)
      end

      if (fallback_category = fallback_category_for(@transaction.description))
        return result_from_fallback(fallback_category)
      end

      nil
    end

    private

    attr_reader :transaction

    def find_alias(analysis)
      analysis.match_candidates.each do |candidate|
        found = @user.merchant_aliases.find_by(normalized_merchant: candidate)
        return found if found
      end

      nil
    end

    def fallback_category_for(description)
      d = description.to_s.upcase

      return category_by_name('Alimentação') if d.include?('IFOOD')

      if d.include?('PAGUE MENOS') || d.include?('DROGASIL') || d.include?('DROGA RAIA') || d.include?('EXTRAFARMA')
        return category_by_name('Saúde')
      end

      if d.include?('POSTO') || d.include?('SHELL') || d.include?('IPIRANGA') || d.include?('PETROBRAS') || d.include?('ALE')
        return category_by_name('Transporte')
      end

      if d.include?('UBER') && (d.include?('EATS') || d.include?('UBER EATS'))
        return category_by_name('Alimentação')
      end

      return category_by_name('Transporte') if d.include?('UBER')

      nil
    end

    def category_by_name(name)
      @category_cache ||= {}
      @category_cache[name] ||= @user.categories.find_by(name: name)
    end

    def result_from_alias(alias_record)
      Result.new(
        suggested_category: alias_record.category,
        confidence: alias_record.confidence,
        source: :alias
      )
    end

    def result_from_fallback(category)
      Result.new(
        suggested_category: category,
        confidence: 0.6,
        source: :rule
      )
    end
  end
end
