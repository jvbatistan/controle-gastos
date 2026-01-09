FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Categoria #{n}" }
  end
end