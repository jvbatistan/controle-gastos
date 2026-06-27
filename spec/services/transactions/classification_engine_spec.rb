require 'rails_helper'

RSpec.describe Transactions::ClassificationEngine do
  describe '.call' do
    let(:user) { create(:user) }

    it 'returns the first matching merchant alias result before deterministic rules' do
      transport_category = create(:category, user: user, name: 'Transporte')
      food_category = create(:category, user: user, name: 'Alimentação')

      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'IFOOD',
        category: transport_category,
        confidence: 0.99,
        source: :user_override
      )

      transaction = build(
        :transaction,
        user: user,
        description: 'Ifood pedido 123',
        category: nil
      )

      result = described_class.call(transaction)

      expect(result).to be_a(Transactions::ClassificationResult)
      expect(result.suggested_category).to eq(transport_category)
      expect(result.suggested_category).not_to eq(food_category)
      expect(result.confidence).to eq(BigDecimal('0.99'))
      expect(result.source).to eq(:alias)
    end

    it 'falls back to a deterministic rule when no alias matches' do
      food_category = create(:category, user: user, name: 'Alimentação')

      transaction = build(
        :transaction,
        user: user,
        description: 'Ifood pedido 123',
        category: nil
      )

      result = described_class.call(transaction)

      expect(result.suggested_category).to eq(food_category)
      expect(result.confidence).to eq(0.6)
      expect(result.source).to eq(:rule)
    end

    it 'returns nil when the transaction is already categorized' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = build(
        :transaction,
        user: user,
        description: 'Uber Trip 1234',
        category: category
      )

      expect(described_class.call(transaction)).to be_nil
    end

    it 'returns nil when no classifier finds a category' do
      transaction = build(
        :transaction,
        user: user,
        description: 'Loja XPTO Centro',
        category: nil
      )

      expect(described_class.call(transaction)).to be_nil
    end
  end
end
