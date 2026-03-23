require 'rails_helper'

RSpec.describe 'Api::ClassificationSuggestions', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /api/classification_suggestions' do
    it 'lists pending suggestions with transaction data' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER TRIP 1234',
        value: 32.9,
        date: Date.current,
        kind: :expense,
        source: :cash
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      get '/api/classification_suggestions'

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.size).to eq(1)
      expect(body.first['id']).to eq(suggestion.id)
      expect(body.first.dig('financial_transaction', 'id')).to eq(transaction.id)
      expect(body.first.dig('suggested_category', 'id')).to eq(category.id)
    end
  end

  describe 'POST /api/classification_suggestions/:id/accept' do
    it 'accepts the suggestion and learns the alias' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER TRIP 1234',
        value: 32.9,
        date: Date.current,
        kind: :expense,
        source: :cash
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      post "/api/classification_suggestions/#{suggestion.id}/accept"

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload
      body = JSON.parse(response.body)

      expect(transaction.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER').category_id).to eq(category.id)
      expect(body.dig('financial_transaction', 'classification_status')).to eq('classified')
    end
  end

  describe 'POST /api/classification_suggestions/:id/reject' do
    it 'rejects the suggestion' do
      transaction = user.transactions.create!(
        description: 'LOJA XPTO',
        value: 50,
        date: Date.current,
        kind: :expense,
        source: :cash
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/reject"

      expect(response).to have_http_status(:ok)

      suggestion.reload
      body = JSON.parse(response.body)

      expect(suggestion.rejected_at).to be_present
      expect(body['rejected_at']).to be_present
    end
  end

  describe 'POST /api/classification_suggestions/:id/correct' do
    it 'corrects the suggestion and learns the alias' do
      corrected_category = create(:category, user: user, name: 'Alimentacao')
      suggested_category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER EATS PEDIDO 123',
        value: 44.5,
        date: Date.current,
        kind: :expense,
        source: :cash
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/correct", params: {
        classification_suggestion: { category_id: corrected_category.id }
      }

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload
      body = JSON.parse(response.body)

      expect(transaction.category_id).to eq(corrected_category.id)
      expect(suggestion.rejected_at).to be_present
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER EATS').category_id).to eq(corrected_category.id)
      expect(body.dig('financial_transaction', 'category', 'id')).to eq(corrected_category.id)
    end
  end
end
