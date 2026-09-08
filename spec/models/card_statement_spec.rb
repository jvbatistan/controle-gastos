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
    expect(statement.payment_status).to eq('partially_paid')
  end

  it 'derives open, partially paid and paid statuses without persistence' do
    statement = create(:card_statement, total_amount: 100, paid_amount: 0)
    account = create(:account, user: statement.card.user, initial_balance: 100)

    expect(statement.payment_status).to eq('open')

    statement.apply_payment!(40, account: account)
    expect(statement.reload.payment_status).to eq('partially_paid')

    statement.apply_payment!(60, account: account)
    expect(statement.reload.payment_status).to eq('paid')
  end

  describe '#apply_payment!' do
    it 'accepts a partial payment below the remaining amount' do
      statement = create(:card_statement, total_amount: 100, paid_amount: 0)
      account = create(:account, user: statement.card.user, initial_balance: 100)

      statement.apply_payment!(40, account: account)

      expect(statement.reload.card_statement_payments.count).to eq(1)
      expect(statement.card_statement_payments.first.account).to eq(account)
      expect(statement.paid_amount.to_d).to eq(BigDecimal('40'))
      expect(statement.remaining_amount).to eq(BigDecimal('60'))
      expect(statement.paid?).to eq(false)
    end

    it 'accepts a payment equal to the remaining amount' do
      statement = create(:card_statement, total_amount: 100, paid_amount: 0)
      account = create(:account, user: statement.card.user, initial_balance: 100)
      create(:card_statement_payment, card_statement: statement, amount: 30)

      statement.apply_payment!(70, account: account)

      expect(statement.reload.card_statement_payments.count).to eq(2)
      expect(statement.paid_amount.to_d).to eq(BigDecimal('100'))
      expect(statement.remaining_amount).to eq(BigDecimal('0'))
      expect(statement.paid?).to eq(true)
    end

    it 'requires an account for a new manual payment' do
      statement = create(:card_statement, total_amount: 100, paid_amount: 0)

      expect do
        statement.apply_payment!(40, account: nil)
      end.to raise_error(ArgumentError, 'Conta é obrigatória para pagar fatura.')
      expect(statement.card_statement_payments.count).to eq(0)
    end

    it 'rejects a payment greater than the remaining amount without creating a payment' do
      statement = create(:card_statement, total_amount: 100, paid_amount: 0)
      account = create(:account, user: statement.card.user)
      create(:card_statement_payment, card_statement: statement, amount: 30)

      expect do
        statement.apply_payment!(71, account: account)
      end.to raise_error(CardStatement::PaymentExceedsRemainingAmount, 'Pagamento excede o saldo restante da fatura. Saldo atual: 70.0')
      expect(CardStatementPayment.count).to eq(1)

      expect(statement.reload.paid_amount.to_d).to eq(BigDecimal('30'))
      expect(statement.remaining_amount).to eq(BigDecimal('70'))
    end

    it 'rejects a new payment when the statement is already fully paid' do
      statement = create(:card_statement, total_amount: 100, paid_amount: 0)
      account = create(:account, user: statement.card.user)
      create(:card_statement_payment, card_statement: statement, amount: 100)

      expect do
        statement.apply_payment!(1, account: account)
      end.to raise_error(CardStatement::AlreadyPaid, 'Fatura já está quitada.')
      expect(CardStatementPayment.count).to eq(1)

      expect(statement.reload.paid_amount.to_d).to eq(BigDecimal('100'))
      expect(statement.remaining_amount).to eq(BigDecimal('0'))
    end
  end
end
