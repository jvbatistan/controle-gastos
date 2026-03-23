require 'rails_helper'

RSpec.describe Transactions::SuggestCategoryService do
  describe '#call' do
    let(:user) { create(:user) }
    let(:transport_category) { create(:category, user: user, name: 'Transporte') }
    let(:health_category) { create(:category, user: user, name: 'Saúde') }

    it 'matches a relevant token from left to right' do
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'SUPERMERCADO',
        category: transport_category,
        confidence: 0.98,
        source: :user_override
      )

      transaction = build(
        :transaction,
        user: user,
        description: 'Compra supermercado extra bairro',
        category: nil
      )

      result = described_class.new(transaction).call

      expect(result.suggested_category).to eq(transport_category)
      expect(result.source).to eq(:alias)
    end

    it 'does not prioritize the last token just because it appears later' do
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'SUPERMERCADO',
        category: transport_category,
        confidence: 0.98,
        source: :user_override
      )
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'EXTRA',
        category: health_category,
        confidence: 0.98,
        source: :user_override
      )

      transaction = build(
        :transaction,
        user: user,
        description: 'Compra supermercado extra bairro',
        category: nil
      )

      result = described_class.new(transaction).call

      expect(result.suggested_category).to eq(transport_category)
    end

    it 'matches normalized tokens with accents removed' do
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'FARMACIA',
        category: health_category,
        confidence: 0.98,
        source: :user_override
      )

      transaction = build(
        :transaction,
        user: user,
        description: 'Farmácia São José',
        category: nil
      )

      result = described_class.new(transaction).call

      expect(result.suggested_category).to eq(health_category)
      expect(result.source).to eq(:alias)
    end
  end
end
