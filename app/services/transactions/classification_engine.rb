module Transactions
  class ClassificationEngine
    CLASSIFIERS = [
      Transactions::Classifiers::MerchantAliasClassifier,
      Transactions::Classifiers::DeterministicRuleClassifier
    ].freeze

    def self.call(transaction)
      new(transaction).call
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      return nil if @transaction.category_id.present?

      CLASSIFIERS.each do |classifier|
        result = classifier.call(@transaction)
        return result if result
      end

      nil
    end
  end
end
