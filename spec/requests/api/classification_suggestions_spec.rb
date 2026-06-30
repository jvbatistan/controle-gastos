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

    it 'does not accept a historically inconsistent suggestion pointing to another user category' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      own_category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash)
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: own_category,
        confidence: 0.97,
        source: :alias
      )
      suggestion.update_column(:suggested_category_id, other_category.id)

      post "/api/classification_suggestions/#{suggestion.id}/accept"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end
  end

  describe 'POST /api/classification_suggestions/:id/apply' do
    it 'applies the category without learning an alias when learn is false' do
      category = create(:category, user: user, name: 'Excecao')
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id,
        learn: false
      }, as: :json

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload
      body = JSON.parse(response.body)

      expect(transaction.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
      expect(body.dig('financial_transaction', 'category', 'id')).to eq(category.id)
      expect(body.dig('financial_transaction', 'classification_status')).to eq('classified')
    end

    it 'applies the category and learns an alias when learn is true' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload

      expect(transaction.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER').category_id).to eq(category.id)
    end

    it 'updates an existing alias when learn is true' do
      old_category = create(:category, user: user, name: 'Antiga')
      new_category = create(:category, user: user, name: 'Nova')
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'UBER',
        category: old_category,
        confidence: 0.95,
        source: :user_override
      )
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: new_category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER').category_id).to eq(new_category.id)
      expect(user.merchant_aliases.where(normalized_merchant: 'UBER').count).to eq(1)
    end

    it 'requires category_id without changing records' do
      category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        learn: true
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq('error' => 'category_id is required')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'requires learn without changing records' do
      category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq('error' => 'learn is required')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'rejects invalid learn values without changing records' do
      category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id,
        learn: 'maybe'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq('error' => 'learn must be a boolean')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'does not apply or learn a category from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: other_category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'does not reveal or apply a suggestion from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      other_transaction = create(:transaction, user: other_user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      other_transaction.classification_suggestions.delete_all
      other_suggestion = other_user.classification_suggestions.create!(
        financial_transaction: other_transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{other_suggestion.id}/apply", params: {
        category_id: other_category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(other_transaction.reload.category_id).to be_nil
      expect(other_suggestion.reload.accepted_at).to be_nil
      expect(other_suggestion.rejected_at).to be_nil
      expect(other_user.merchant_aliases).to be_empty
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

    it 'corrects the suggestion without learning an alias when merchant normalizes to blank' do
      corrected_category = create(:category, user: user, name: 'Alimentacao')
      suggested_category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: '1234 - 5678',
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

      expect(transaction.category_id).to eq(corrected_category.id)
      expect(suggestion.rejected_at).to be_present
      expect(user.merchant_aliases).to be_empty
    end

    it 'does not apply or learn an alias for a category from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      suggested_category = create(:category, user: user)
      transaction = create(
        :transaction,
        user: user,
        card: nil,
        category: nil,
        source: :cash,
        description: 'Uber Eats Pedido'
      )
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/correct", params: {
        classification_suggestion: { category_id: other_category.id }
      }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end
  end
end
