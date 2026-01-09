require "rails_helper"

RSpec.describe Debts::CreateService do
  let(:category) { create(:category) }
  let(:card) { create(:card) }

  let(:params) do {
    description: "Teste",
    value: 100,
    transaction_date: Date.today,
    card_id: card.id,
    category_id: category.id,
    responsible: "JV" }
  end

  subject(:result) { described_class.new(params).call }

  it "creates a debt" do
    expect { result }.to change(Debt, :count).by(1)
  end

  it "creates a transaction" do
    expect { result }.to change(Transaction, :count).by(1)
  end

  it "links the debt to the transaction" do
    result
    debt = result.debt
    
    expect(debt.financial_transaction).to be_present
  end

  it "copies basic attributes to the transaction" do
    result
    tx = result.debt.financial_transaction

    expect(tx.description).to eq("TESTE")
    expect(tx.value).to eq(100)
    expect(tx.category_id).to eq(category.id)
    expect(tx.card_id).to eq(card.id)
  end
end
  # describe "#call" do
  #   it "cria a dívida e gera as parcelas futuras quando has_installment=true" do
  #     card = Card.create!(name: "Nubank", due_date: 10, closing_date: 7)

  #     params = {
  #       description: "Celular",
  #       value: "1234,56",
  #       transaction_date: Date.today,
  #       card_id: card.id,
  #       has_installment: true,
  #       current_installment: 1,
  #       final_installment: 3,
  #       paid: false
  #     }

  #     result = nil

  #     expect {
  #       result = described_class.new(params).call
  #     }.to change(Debt, :count).by(3)

  #     expect(result).to be_success

  #     parent = result.debt

  #     expect(parent.parent_id).to be_nil
  #     expect(parent.current_installment).to eq(1)
  #     expect(parent.final_installment).to eq(3)

  #     children = Debt.where(parent_id: parent.id).order(:current_installment)
  #     expect(children.pluck(:current_installment)).to eq([2, 3])

  #     expect(children.first.transaction_date).to eq(parent.transaction_date + 1.month)
  #     expect(children.last.transaction_date).to eq(parent.transaction_date + 2.months)
  #   end
  # end
# end