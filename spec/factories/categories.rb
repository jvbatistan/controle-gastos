FactoryBot.define do
  factory :category do
    association :user

    sequence(:name) { |n| "Categoria #{n}" }
  end
end
