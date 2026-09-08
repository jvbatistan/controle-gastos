require 'rails_helper'

RSpec.describe Transactions::RegisterPaymentService do
  let(:user) { create(:user) }
  let(:planned_account) { create(:account, user: user, initial_balance: 2_000) }
  let(:account_a) { create(:account, user: user, initial_balance: 2_000) }
  let(:account_b) { create(:account, user: user, initial_balance: 2_000) }
  let(:transaction) { create(:transaction, user: user, kind: :expense, source: :cash, card: nil, account: planned_account, value: 1_000, paid: false, settled_on: nil, settled_value: nil) }

  def pay(transaction, account:, amount:, settled_on: Date.new(2026, 9, 10), settle: false)
    described_class.new(transaction: transaction, account: account, amount: amount, settled_on: settled_on, settle: settle).call
  end

  it 'records independent partial payments without using legacy settlement fields' do
    first = pay(transaction, account: account_a, amount: 300)
    second = pay(transaction, account: account_b, amount: 200, settled_on: Date.new(2026, 9, 15))

    expect([first.payment.amount, second.payment.amount]).to eq([300.to_d, 200.to_d])
    expect(transaction.reload).to have_attributes(value: 1_000.to_d, paid: false, settled_on: nil, settled_value: nil, payments_total: 500.to_d, remaining_amount: 500.to_d, payment_status: 'partially_paid')
    expect(transaction.transaction_payments.pluck(:account_id)).to contain_exactly(account_a.id, account_b.id)
  end

  it 'settles for a lower explicit total without inventing a payment' do
    pay(transaction, account: account_a, amount: 500)
    pay(transaction, account: account_b, amount: 450, settle: true)

    expect(transaction.reload).to have_attributes(paid: true, payments_total: 950.to_d, remaining_amount: 50.to_d, payment_status: 'paid', settled_value: nil)
    expect(transaction.transaction_payments.count).to eq(2)
  end

  it 'allows an overpayment only when explicitly settling and rejects a later payment atomically' do
    pay(transaction, account: account_a, amount: 900)
    expect { pay(transaction, account: account_b, amount: 150) }.to raise_error(ArgumentError, /exige quitação explícita/)
    expect(transaction.transaction_payments.count).to eq(1)

    pay(transaction, account: account_b, amount: 150, settle: true)
    expect(transaction.reload).to have_attributes(paid: true, payments_total: 1_050.to_d, remaining_amount: -50.to_d)
    expect { pay(transaction, account: account_a, amount: 1) }.to raise_error(ArgumentError, /já está quitada/)
    expect(transaction.transaction_payments.count).to eq(2)
  end

  it 'rejects inactive and cross-user accounts without persisting a payment' do
    account_a.archive!
    other_account = create(:account)

    expect { pay(transaction, account: account_a, amount: 10) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { pay(transaction, account: other_account, amount: 10) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(transaction.transaction_payments).to be_empty
  end
end
