FactoryBot.define do
  factory :debt do
    description       { "COMPRA TESTE" }
    value             { 100.0 }
    transaction_date  { Date.today }
    billing_statement { nil }  # o service que vai preencher

    paid             { false }
    has_installment  { false }
    current_installment { nil }
    final_installment   { nil }
    responsible      { "JOÃO" }
    note             { nil }
    parent_id        { nil }

    expense_type { :single }

    association :card
    association :category, factory: :category, strategy: :build if defined?(Category)

    # se quiser, cria também uma factory de category:
    # factory :category do
    #   name { "MERCADO" }
    # end
  end
end
