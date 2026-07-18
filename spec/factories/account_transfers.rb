FactoryBot.define do
  factory :account_transfer do
    association :user

    from_account { association(:account, user: user) }
    to_account { association(:account, user: user) }
    amount { 100 }
    transferred_on { Date.current }
    description { "Transferência entre contas" }
    note { nil }
    status { :completed }

    trait :reversed do
      status { :reversed }
    end
  end
end
