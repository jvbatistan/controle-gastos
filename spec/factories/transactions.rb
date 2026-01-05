FactoryBot.define do
  factory :transaction do
    description { Faker::Commerce.product_name }
    value { rand(10..500) }
    date { Date.today }
    
    kind { :expense }
    source { :card }

    paid        { false }
    note        { nil }
    responsible { "JOÃO" }
    
    association :card
  end
end