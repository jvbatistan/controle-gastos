require "rails_helper"

RSpec.describe Debts::CreateService do
  describe "#call" do
    it "cria a dívida e gera as parcelas futuras quando has_installment=true" do
      card = Card.create!(name: "Nubank", due_date: 10, closing_date: 7)

      params = {
        description: "Celular",
        value: "1234,56",
        transaction_date: Date.today,
        card_id: card.id,
        has_installment: true,
        current_installment: 1,
        final_installment: 3,
        paid: false
      }

      result = nil

      expect {
        result = described_class.new(params).call
      }.to change(Debt, :count).by(3)

      expect(result).to be_success

      parent = result.debt

      expect(parent.parent_id).to be_nil
      expect(parent.current_installment).to eq(1)
      expect(parent.final_installment).to eq(3)

      children = Debt.where(parent_id: parent.id).order(:current_installment)
      expect(children.pluck(:current_installment)).to eq([2, 3])

      expect(children.first.transaction_date).to eq(parent.transaction_date + 1.month)
      expect(children.last.transaction_date).to eq(parent.transaction_date + 2.months)
    end
  end
end