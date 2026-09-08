require 'rails_helper'

RSpec.describe Accounts::BalanceAtDateCalculator do
  describe '.call' do
    it 'includes initial balance only when initial_balance_date is on or before the cutoff' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 500, initial_balance_date: Date.new(2026, 7, 10))

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 9))).to eq(0.to_d)
      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 10))).to eq(500.to_d)
      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 11))).to eq(500.to_d)
    end

    it 'handles zero initial balance' do
      account = create(:account, initial_balance: 0, initial_balance_date: Date.new(2026, 7, 1))

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 1))).to eq(0.to_d)
    end

    it 'includes incomes up to the cutoff date and excludes later incomes' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 100, initial_balance_date: Date.new(2026, 7, 1))
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 50, date: Date.new(2026, 7, 4))
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 70, date: Date.new(2026, 7, 5))
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 90, date: Date.new(2026, 7, 6))

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 5))).to eq(220.to_d)
    end

    it 'subtracts cash and bank expenses up to the cutoff and excludes card purchases' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 500, initial_balance_date: Date.new(2026, 7, 1))
      card = create(:card, user: user)
      create(:transaction, user: user, kind: :expense, source: :cash, account: account, card: nil, value: 40, date: Date.new(2026, 7, 5), paid: true)
      create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 60, date: Date.new(2026, 7, 5), paid: true)
      create(:transaction, user: user, kind: :expense, source: :card, account: nil, card: card, value: 100, date: Date.new(2026, 7, 5))
      create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 20, date: Date.new(2026, 7, 6), paid: true)

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 5))).to eq(400.to_d)
    end

    it 'uses settlement date and value when they are available' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 500, initial_balance_date: Date.new(2026, 8, 1))
      create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 150, paid: true, date: Date.new(2026, 8, 18), settled_on: Date.new(2026, 8, 10), settled_value: 149.26)

      expect(described_class.call(account: account, as_of: Date.new(2026, 8, 9))).to eq(500.to_d)
      expect(described_class.call(account: account, as_of: Date.new(2026, 8, 10))).to eq(350.74.to_d)
    end

    it 'excludes archived transactions and transactions without account' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 300, initial_balance_date: Date.new(2026, 7, 1))
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 100, archived_at: Time.current, date: Date.new(2026, 7, 5))
      legacy_expense = create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 50, date: Date.new(2026, 7, 5))
      legacy_expense.update_column(:account_id, nil)

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 5))).to eq(300.to_d)
    end

    it 'subtracts statement payments up to the cutoff and excludes later or accountless payments' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 500, initial_balance_date: Date.new(2026, 7, 1))
      card = create(:card, user: user)
      statement = create(:card_statement, card: card)
      create(:card_statement_payment, card_statement: statement, account: account, amount: 100, paid_at: Time.zone.local(2026, 7, 5, 23, 59), description: 'Pagamento 1')
      create(:card_statement_payment, card_statement: statement, account: account, amount: 200, paid_at: Time.zone.local(2026, 7, 6, 0, 1), description: 'Pagamento 2')
      create(:card_statement_payment, card_statement: statement, account: nil, amount: 300, paid_at: Time.zone.local(2026, 7, 5, 12), description: 'Pagamento legado')

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 5))).to eq(400.to_d)
    end

    it 'applies completed transfers up to the cutoff and excludes later or reversed transfers' do
      user = create(:user)
      checking = create(:account, user: user, initial_balance: 500, initial_balance_date: Date.new(2026, 7, 1))
      savings = create(:account, user: user, initial_balance: 100, initial_balance_date: Date.new(2026, 7, 1))
      create(:account_transfer, user: user, from_account: checking, to_account: savings, amount: 80, transferred_on: Date.new(2026, 7, 4))
      create(:account_transfer, user: user, from_account: savings, to_account: checking, amount: 30, transferred_on: Date.new(2026, 7, 5))
      create(:account_transfer, user: user, from_account: checking, to_account: savings, amount: 70, transferred_on: Date.new(2026, 7, 6))
      create(:account_transfer, :reversed, user: user, from_account: savings, to_account: checking, amount: 999, transferred_on: Date.new(2026, 7, 5))

      expect(described_class.call(account: checking, as_of: Date.new(2026, 7, 5))).to eq(450.to_d)
      expect(described_class.call(account: savings, as_of: Date.new(2026, 7, 5))).to eq(150.to_d)
    end

    it 'allows negative balances' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 10, initial_balance_date: Date.new(2026, 7, 1))
      create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 40, date: Date.new(2026, 7, 2), paid: true)

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 2))).to eq(-30.to_d)
    end

    it 'calculates archived accounts when directly consulted' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 100, initial_balance_date: Date.new(2026, 7, 1))
      create(:transaction, user: user, kind: :income, source: :cash, account: account, card: nil, value: 25, date: Date.new(2026, 7, 2))
      account.archive!

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 2))).to eq(125.to_d)
    end

    it 'ignores inconsistent cross-user records pointing to the account' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 100, initial_balance_date: Date.new(2026, 7, 1))
      other_user = create(:user)
      other_account = create(:account, user: other_user)

      foreign_transaction = create(:transaction, user: other_user, kind: :income, source: :bank, account: other_account, card: nil, value: 900, date: Date.new(2026, 7, 2))
      foreign_transaction.update_column(:account_id, account.id)

      foreign_card = create(:card, user: other_user)
      foreign_statement = create(:card_statement, card: foreign_card)
      foreign_payment = create(:card_statement_payment, card_statement: foreign_statement, account: other_account, amount: 800, paid_at: Time.zone.local(2026, 7, 2), description: 'Pagamento externo')
      foreign_payment.update_column(:account_id, account.id)

      foreign_transfer = create(:account_transfer, user: other_user, from_account: other_account, to_account: create(:account, user: other_user), amount: 700, transferred_on: Date.new(2026, 7, 2))
      foreign_transfer.update_column(:from_account_id, account.id)

      expect(described_class.call(account: account, as_of: Date.new(2026, 7, 2))).to eq(100.to_d)
    end

    it 'uses financial dates so retroactive movements affect historical balances' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 100, initial_balance_date: Date.new(2026, 7, 1))
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 50, date: Date.new(2026, 6, 20), created_at: Time.zone.local(2026, 7, 20))

      expect(described_class.call(account: account, as_of: Date.new(2026, 6, 30))).to eq(50.to_d)
    end

    it 'matches BalanceCalculator when cutoff covers all events' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 1000, initial_balance_date: Date.new(2026, 7, 1))
      card = create(:card, user: user)
      statement = create(:card_statement, card: card)
      savings = create(:account, user: user)

      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 300, date: Date.new(2026, 7, 5))
      create(:transaction, user: user, kind: :expense, source: :cash, account: account, card: nil, value: 120, date: Date.new(2026, 7, 6), paid: true)
      create(:card_statement_payment, card_statement: statement, account: account, amount: 80, paid_at: Time.zone.local(2026, 7, 7), description: 'Pagamento final')
      create(:account_transfer, user: user, from_account: account, to_account: savings, amount: 50, transferred_on: Date.new(2026, 7, 8))
      create(:account_transfer, user: user, from_account: savings, to_account: account, amount: 10, transferred_on: Date.new(2026, 7, 9))

      expect(described_class.call(account: account, as_of: Date.new(2026, 12, 31))).to eq(Accounts::BalanceCalculator.call(account))
    end

    it 'uses each payment civil date instead of the transaction competence date' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 1_000, initial_balance_date: Date.new(2026, 9, 1))
      transaction = create(:transaction, user: user, kind: :expense, source: :cash, card: nil, account: account, value: 1_000, date: Date.new(2026, 9, 1), paid: true)
      transaction.update_columns(settled_on: nil, settled_value: nil)
      TransactionPayment.create!(financial_transaction: transaction, account: account, amount: 300, settled_on: Date.new(2026, 9, 10))
      TransactionPayment.create!(financial_transaction: transaction, account: account, amount: 200, settled_on: Date.new(2026, 9, 15))

      expect(described_class.call(account: account, as_of: Date.new(2026, 9, 9))).to eq(1_000.to_d)
      expect(described_class.call(account: account, as_of: Date.new(2026, 9, 10))).to eq(700.to_d)
      expect(described_class.call(account: account, as_of: Date.new(2026, 9, 15))).to eq(500.to_d)
    end
  end
end
