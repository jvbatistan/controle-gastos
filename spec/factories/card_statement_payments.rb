FactoryBot.define do
  factory :card_statement_payment do
    association :card_statement

    amount { 100 }
    paid_at { Time.zone.now }
    description { "Pagamento da fatura" }
    source { "manual" }
  end
end
