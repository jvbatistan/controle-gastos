FactoryBot.define do
  factory :transaction do
    association :user
    card { association :card, user: user }

    description { Faker::Commerce.product_name }
    value { rand(10..500) }
    date { Date.today }
    purchase_date { nil }
    original_value { nil }
    kind { :expense }
    source { :card }
    account { source.to_s == 'card' ? nil : association(:account, user: user) }
    refund { false }
    paid { false }
    note { nil }
    responsible { 'JOAO' }
  end
end
