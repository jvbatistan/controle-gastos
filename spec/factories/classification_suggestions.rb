FactoryBot.define do
  factory :classification_suggestion do
    association :user
    financial_transaction { association :transaction, user: user }
    suggested_category { association :category, user: user }
    confidence { 0.6 }
    source { :rule }
  end
end
