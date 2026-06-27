module Transactions
  module Classifiers
    class MerchantAliasClassifier
      def self.call(transaction)
        new(transaction).call
      end

      def initialize(transaction)
        @transaction = transaction
        @user = transaction.user
      end

      def call
        analysis = Merchants::DescriptionAnalysis.call(@transaction.description)
        alias_record = find_alias(analysis)
        return nil if alias_record.nil?

        category = @user.categories.find_by(id: alias_record.category_id)
        return nil if category.nil?

        Transactions::ClassificationResult.new(
          suggested_category: category,
          confidence: alias_record.confidence,
          source: :alias
        )
      end

      private

      def find_alias(analysis)
        analysis.match_candidates.each do |candidate|
          found = @user.merchant_aliases.find_by(normalized_merchant: candidate)
          return found if found
        end

        nil
      end
    end
  end
end
