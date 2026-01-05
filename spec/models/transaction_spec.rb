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
end
