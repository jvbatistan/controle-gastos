require 'rails_helper'

RSpec.describe Transaction, type: :model do
  describe 'associations' do
    it { should belong_to(:card).optional }
    it { should belong_to(:category).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:value) }
    it { should validate_numericality_of(:value).is_greater_than(0) }

    it { should validate_presence_of(:date) }
    it { should validate_presence_of(:kind) }
    it { should validate_presence_of(:source) }

    it 'requires card expense fields for refunds' do
      transaction = build(:transaction, refund: true, source: :cash, card: nil)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:source]).to include('deve ser cartão para estornos')
      expect(transaction.errors[:card]).to include('é obrigatório para estornos')
    end

    it 'rejects clear card statement payment descriptions as transactions' do
      transaction = build(:transaction, description: 'Pagamento recebido para liberar limite', source: :card, refund: false)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:base]).to include('pagamento de fatura deve ser registrado na tela de pagamentos, não como transação')
    end

    it 'rejects the exact generic payment description without matching normal merchants' do
      payment = build(:transaction, description: 'Pagamento', source: :card, refund: false)

      expect(payment).not_to be_valid
      expect(payment.errors[:base]).to include('pagamento de fatura deve ser registrado na tela de pagamentos, não como transação')
    end

    it 'does not reject merchant names that include payment-like words' do
      transaction = build(:transaction, description: 'Pagamento de farmacia sao jose', source: :card, refund: false)

      expect(transaction).to be_valid
    end
  end
  
  describe 'enums' do
    it do
      expect(described_class.kinds).to eq(
        'income'  => 0,
        'expense' => 1
      )
    end

    it do
      expect(described_class.sources).to eq(
        'card' => 0,
        'cash' => 1,
        'bank' => 2
      )
    end
  end

  describe 'scopes and totals' do
    describe '.by_month' do
      it 'retorna apenas transações do mês/ano informados' do
        nov_2025 = create(:transaction, date: Date.new(2025, 11, 10))
        out_2025 = create(:transaction, date: Date.new(2025, 10, 5))

        result = Transaction.by_month(11, 2025)

        expect(result).to include(nov_2025)
        expect(result).not_to include(out_2025)
      end
    end

    describe '.balance_for' do
      it 'retorna receitas - despesas do mês/ano informado' do
        data = Date.new(2025, 11, 1)

        create(:transaction, kind: :income,  value: 1000.0, date: data)
        create(:transaction, kind: :expense, value:  200.0, date: data)

        expect(Transaction.balance_for(11, 2025)).to eq(800.0)
      end
    end
  end

  describe '#signed_value' do
    it 'returns value for regular transactions and negative value for refunds' do
      regular = build(:transaction, value: 20, refund: false)
      refund = build(:transaction, value: 6.92, refund: true)

      expect(regular.signed_value).to eq(BigDecimal('20'))
      expect(refund.signed_value).to eq(BigDecimal('-6.92'))
    end

    it 'normalizes the raw sign without changing the explicit transaction type' do
      purchase = build(:transaction, value: '-11,02', refund: false)
      refund = build(:transaction, value: '-6,91', refund: true)

      expect(purchase.value).to eq(BigDecimal('11.02'))
      expect(purchase.signed_value).to eq(BigDecimal('11.02'))
      expect(refund.value).to eq(BigDecimal('6.91'))
      expect(refund.signed_value).to eq(BigDecimal('-6.91'))
    end
  end
end
