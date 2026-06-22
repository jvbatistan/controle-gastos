FactoryBot.define do
  factory :card_statement do
    association :card

    billing_statement { Date.current.beginning_of_month }
    total_amount { 0 }
    paid_amount { 0 }
  end
end
