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

  it 'allows a payment that uses exactly the available account balance' do
    account_a.update!(initial_balance: 300)

    pay(transaction, account: account_a, amount: 300)

    expect(Accounts::BalanceCalculator.call(account_a)).to eq(0.to_d)
    expect(transaction.reload).to have_attributes(paid: false, payments_total: 300.to_d, remaining_amount: 700.to_d)
  end

  it 'rejects an insufficient partial payment without persisting a payment or statement movement' do
    account_a.update!(initial_balance: 299)

    expect { pay(transaction, account: account_a, amount: 300) }
      .to raise_error(Accounts::DebitGuard::InsufficientFunds, /Saldo insuficiente/)

    expect(transaction.reload).to have_attributes(paid: false, payments_total: 0.to_d)
    expect(Accounts::BalanceCalculator.call(account_a)).to eq(299.to_d)
    expect(Accounts::StatementBuilder.call(account: account_a, paginate: false).items.none? { |item| item.source_type == 'transaction_payment' }).to eq(true)
  end

  it 'settles for a lower explicit total without inventing a payment' do
    pay(transaction, account: account_a, amount: 500)
    pay(transaction, account: account_b, amount: 450, settle: true)

    expect(transaction.reload).to have_attributes(paid: true, payments_total: 950.to_d, remaining_amount: 50.to_d, payment_status: 'paid', settled_value: nil)
    expect(transaction.transaction_payments.count).to eq(2)
  end

  it 'settles through an active payment account when the legacy planned account is archived' do
    transaction.reload
    planned_account.archive!
    transaction.reload

    result = pay(transaction, account: account_a, amount: 147.97, settle: true)

    expect(result.payment).to have_attributes(account: account_a, amount: 147.97.to_d, settled_on: Date.new(2026, 9, 10))
    expect(transaction.reload).to have_attributes(account_id: planned_account.id, paid: true, payments_total: 147.97.to_d, payment_status: 'paid')
    expect(Accounts::BalanceCalculator.call(account_a)).to eq(1_852.03.to_d)
    expect(Accounts::BalanceCalculator.call(planned_account)).to eq(2_000.to_d)
    expect(Accounts::StatementBuilder.call(account: account_a, paginate: false).items.select { |item| item.source_type == 'transaction_payment' }.map(&:amount)).to eq([147.97.to_d])
    expect(Accounts::StatementBuilder.call(account: planned_account, paginate: false).items.select { |item| item.source_type == 'transaction_payment' }).to be_empty
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

  it 'allows an explicitly settling overpayment only when the account can fund it' do
    account_b.update!(initial_balance: 149)
    pay(transaction, account: account_a, amount: 900)

    expect { pay(transaction, account: account_b, amount: 150, settle: true) }
      .to raise_error(Accounts::DebitGuard::InsufficientFunds, /Necessário: R\$ 150,00/)

    expect(transaction.reload).to have_attributes(paid: false, payments_total: 900.to_d, remaining_amount: 100.to_d)
    expect(Accounts::BalanceCalculator.call(account_b)).to eq(149.to_d)
  end

  it 'rejects inactive and cross-user accounts without persisting a payment' do
    account_a.archive!
    other_account = create(:account)

    expect { pay(transaction, account: account_a, amount: 10) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { pay(transaction, account: other_account, amount: 10) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(transaction.transaction_payments).to be_empty
  end
end
