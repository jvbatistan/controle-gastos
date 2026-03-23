FactoryBot.define do
  factory :transaction do
    association :user
    card { association :card, user: user }

    description { Faker::Commerce.product_name }
    value { rand(10..500) }
    date { Date.today }
    kind { :expense }
    source { :card }
    paid { false }
    note { nil }
    responsible { 'JOAO' }
  end
end
