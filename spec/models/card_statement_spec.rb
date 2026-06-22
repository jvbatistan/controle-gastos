require 'rails_helper'

RSpec.describe CardStatement, type: :model do
  describe 'associations' do
    it { should belong_to(:card) }
    it { should have_many(:card_statement_payments).dependent(:destroy) }
  end

  it 'calculates remaining amount from total amount minus statement payments' do
    statement = create(:card_statement, total_amount: 100)
    create(:card_statement_payment, card_statement: statement, amount: 30)

    expect(statement.reload.paid_amount.to_d).to eq(BigDecimal('30'))
    expect(statement.remaining_amount).to eq(BigDecimal('70'))
  end
end
