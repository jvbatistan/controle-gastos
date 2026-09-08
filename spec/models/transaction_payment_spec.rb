require 'rails_helper'

RSpec.describe TransactionPayment do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:transaction) { create(:transaction, user: user, kind: :expense, source: :bank, card: nil, account: account, paid: false) }

  it 'uses financial_transaction while preserving transaction_id and enforces financial invariants' do
    payment = described_class.new(financial_transaction: transaction, account: account, amount: 10, settled_on: Date.new(2026, 9, 10))
    expect(payment).to be_valid
    payment.save!
    expect(payment.transaction_id).to eq(transaction.id)
    expect(payment.financial_transaction).to eq(transaction)

    expect(described_class.new(financial_transaction: transaction, account: account, amount: 0, settled_on: Date.current)).not_to be_valid
    expect(described_class.new(financial_transaction: transaction, account: account, amount: -1, settled_on: Date.current)).not_to be_valid
  end
end
