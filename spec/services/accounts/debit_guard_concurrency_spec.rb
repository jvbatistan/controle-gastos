require 'rails_helper'
require 'timeout'

RSpec.describe Accounts::DebitGuard, type: :model do
  self.use_transactional_tests = false

  after do
    next unless defined?(@transaction_ids)

    TransactionPayment.where(transaction_id: @transaction_ids).delete_all
    ClassificationSuggestion.where(financial_transaction_id: @transaction_ids).delete_all
    Transaction.where(id: @transaction_ids).delete_all
    Account.where(id: @account_id).delete_all
    User.where(id: @user_id).delete_all
  end

  it 'serializes concurrent debits from the same account so only one can consume the available balance' do
    user = create(:user)
    account = create(:account, user: user, initial_balance: 100)
    first = create(:transaction, user: user, account: account, card: nil, source: :cash, value: 80, paid: false)
    second = create(:transaction, user: user, account: account, card: nil, source: :cash, value: 80, paid: false)
    @user_id = user.id
    @account_id = account.id
    @transaction_ids = [first.id, second.id]

    ready = Queue.new
    release = Queue.new
    results = Queue.new

    workers = [first.id, second.id].map do |transaction_id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          Transactions::RegisterPaymentService.new(
            transaction: Transaction.find(transaction_id), account: Account.find(account.id), amount: 80,
            settled_on: Date.new(2026, 9, 8)
          ).call
          results << :paid
        rescue Accounts::DebitGuard::InsufficientFunds
          results << :insufficient_funds
        end
      end
    end

    Timeout.timeout(5) { 2.times { ready.pop } }
    2.times { release << true }
    workers.each(&:join)

    expect(2.times.map { results.pop }).to contain_exactly(:paid, :insufficient_funds)
    expect(TransactionPayment.where(transaction_id: @transaction_ids).count).to eq(1)
    expect(Accounts::BalanceCalculator.call(account.reload)).to eq(20.to_d)
  end
end
