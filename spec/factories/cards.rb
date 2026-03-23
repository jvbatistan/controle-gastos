FactoryBot.define do
  factory :card do
    association :user

    name { 'NUBANK' }
    due_date { 15 }
    closing_date { 7 }
  end
end
