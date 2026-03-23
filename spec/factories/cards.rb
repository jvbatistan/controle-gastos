FactoryBot.define do
  factory :card do
    association :user

    name { 'NUBANK' }
    due_date { 15 }
    closing_date { 7 }
    due_day { 15 }
    closing_day { 8 }
    limit { 5000 }
  end
end
