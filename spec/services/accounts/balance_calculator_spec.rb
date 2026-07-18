require 'rails_helper'

RSpec.describe Accounts::BalanceCalculator do
  describe '.call' do
    it 'calculates current balance from initial balance, incomes, cash/bank expenses and statement payments' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 1000)
      card = create(:card, user: user)
      statement = create(:card_statement, card: card, total_amount: 300, paid_amount: 0)

      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 250)
      create(:transaction, user: user, kind: :expense, source: :cash, account: account, card: nil, value: 80)
      create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 70)
      create(:card_statement_payment, card_statement: statement, account: account, amount: 120)

      expect(described_class.call(account)).to eq(980.to_d)
    end

    it 'does not include card purchases directly to avoid double counting with statement payments' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 1000)
      card = create(:card, user: user)
      statement = create(:card_statement, card: card, total_amount: 300, paid_amount: 0)

      create(:transaction, user: user, kind: :expense, source: :card, account: nil, card: card, value: 300)
      create(:card_statement_payment, card_statement: statement, account: account, amount: 300)

      expect(described_class.call(account)).to eq(700.to_d)
    end

    it 'subtracts outgoing completed transfers from current balance' do
      user = create(:user)
      from_account = create(:account, user: user, initial_balance: 1000)
      to_account = create(:account, user: user, initial_balance: 500)
      create(:account_transfer, user: user, from_account: from_account, to_account: to_account, amount: 200)

      expect(described_class.call(from_account)).to eq(800.to_d)
    end

    it 'adds incoming completed transfers to current balance' do
      user = create(:user)
      from_account = create(:account, user: user, initial_balance: 1000)
      to_account = create(:account, user: user, initial_balance: 500)
      create(:account_transfer, user: user, from_account: from_account, to_account: to_account, amount: 200)

      expect(described_class.call(to_account)).to eq(700.to_d)
    end

    it 'keeps total patrimony unchanged by transfers between accounts' do
      user = create(:user)
      checking = create(:account, user: user, initial_balance: 1000)
      savings = create(:account, user: user, initial_balance: 500)

      create(:account_transfer, user: user, from_account: checking, to_account: savings, amount: 200)

      balances = described_class.for([checking, savings])
      expect(balances[checking.id]).to eq(800.to_d)
      expect(balances[savings.id]).to eq(700.to_d)
      expect(balances.values.sum).to eq(1500.to_d)
    end

    it 'does not include reversed transfers in current balance' do
      user = create(:user)
      from_account = create(:account, user: user, initial_balance: 1000)
      to_account = create(:account, user: user, initial_balance: 500)

      create(:account_transfer, :reversed, user: user, from_account: from_account, to_account: to_account, amount: 200)

      expect(described_class.for([from_account, to_account])).to eq(
        from_account.id => 1000.to_d,
        to_account.id => 500.to_d
      )
    end

    it 'ignores archived transactions and historical movements without account' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 500)
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 100, archived_at: Time.current)
      historical_expense = create(:transaction, user: user, kind: :expense, source: :cash, account: account, card: nil, value: 60)
      historical_expense.update_column(:account_id, nil)

      expect(described_class.call(account)).to eq(500.to_d)
    end

    it 'does not use payment_ignored_at or paid to filter cash movements' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 500)
      create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 90, paid: false, payment_ignored_at: Time.current)

      expect(described_class.call(account)).to eq(410.to_d)
    end

    it 'calculates balance for archived accounts when they are directly consulted' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 200)
      create(:transaction, user: user, kind: :income, source: :cash, account: account, card: nil, value: 50)

      account.archive!

      expect(described_class.call(account)).to eq(250.to_d)
    end
  end

  describe '.for' do
    it 'returns balances for multiple accounts with independent aggregates' do
      user = create(:user)
      nubank = create(:account, user: user, initial_balance: 1000)
      wallet = create(:account, user: user, initial_balance: 100)
      other_account = create(:account, user: create(:user), initial_balance: 999)

      create(:transaction, user: user, kind: :income, source: :bank, account: nubank, card: nil, value: 200)
      create(:transaction, user: user, kind: :expense, source: :cash, account: wallet, card: nil, value: 30)
      create(:transaction, user: other_account.user, kind: :income, source: :bank, account: other_account, card: nil, value: 500)

      expect(described_class.for([nubank, wallet])).to eq(
        nubank.id => 1200.to_d,
        wallet.id => 70.to_d
      )
    end

    it 'ignores transfers from another user when those accounts are not being calculated' do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 300)
      other_user = create(:user)
      other_from = create(:account, user: other_user, initial_balance: 1000)
      other_to = create(:account, user: other_user, initial_balance: 500)

      create(:account_transfer, user: other_user, from_account: other_from, to_account: other_to, amount: 250)

      expect(described_class.for([account])).to eq(account.id => 300.to_d)
    end

    it 'handles multiple transfers between the same accounts' do
      user = create(:user)
      checking = create(:account, user: user, initial_balance: 1000)
      savings = create(:account, user: user, initial_balance: 500)

      create(:account_transfer, user: user, from_account: checking, to_account: savings, amount: 100)
      create(:account_transfer, user: user, from_account: checking, to_account: savings, amount: 50)
      create(:account_transfer, user: user, from_account: savings, to_account: checking, amount: 25)

      expect(described_class.for([checking, savings])).to eq(
        checking.id => 875.to_d,
        savings.id => 625.to_d
      )
    end

    it 'combines transfers with income, cash expense and statement payment' do
      user = create(:user)
      checking = create(:account, user: user, initial_balance: 1000)
      savings = create(:account, user: user, initial_balance: 500)
      card = create(:card, user: user)
      statement = create(:card_statement, card: card, total_amount: 80, paid_amount: 0)

      create(:transaction, user: user, kind: :income, source: :bank, account: checking, card: nil, value: 300)
      create(:transaction, user: user, kind: :expense, source: :cash, account: checking, card: nil, value: 120)
      create(:card_statement_payment, card_statement: statement, account: checking, amount: 80)
      create(:account_transfer, user: user, from_account: checking, to_account: savings, amount: 200)

      expect(described_class.for([checking, savings])).to eq(
        checking.id => 900.to_d,
        savings.id => 700.to_d
      )
    end
  end
end
