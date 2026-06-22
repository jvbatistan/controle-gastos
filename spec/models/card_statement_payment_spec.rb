require 'rails_helper'

RSpec.describe CardStatementPayment, type: :model do
  describe 'associations' do
    it { should belong_to(:card_statement) }
    it { should belong_to(:original_transaction).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:paid_at) }
  end

  it 'syncs the card statement paid amount after creation' do
    statement = create(:card_statement, total_amount: 100, paid_amount: 0)

    create(:card_statement_payment, card_statement: statement, amount: 30)

    expect(statement.reload.paid_amount.to_d).to eq(BigDecimal('30'))
    expect(statement.remaining_amount).to eq(BigDecimal('70'))
  end
end
