FactoryBot.define do
  factory :account do
    association :user

    sequence(:name) { |n| "Conta #{n}" }
    kind { :checking }
    initial_balance { 0 }
    initial_balance_date { Date.current }
    archived_at { nil }
  end
end
