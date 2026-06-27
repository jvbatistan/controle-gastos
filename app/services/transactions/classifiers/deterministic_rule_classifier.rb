module Transactions
  module Classifiers
    class DeterministicRuleClassifier
      def self.call(transaction)
        new(transaction).call
      end

      def initialize(transaction)
        @transaction = transaction
        @user = transaction.user
      end

      def call
        category = fallback_category_for(@transaction.description)
        return nil if category.nil?

        Transactions::ClassificationResult.new(
          suggested_category: category,
          confidence: 0.6,
          source: :rule
        )
      end

      private

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
    end
  end
end
