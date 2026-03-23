require 'rails_helper'

RSpec.describe 'Api::Transactions', type: :request do
  describe 'POST /api/transactions' do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it 'auto-classifies when an exact alias exists' do
      category = create(:category, user: user, name: 'Transporte')
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'UBER',
        category: category,
        confidence: 1.0,
        source: :user_override
      )

      post '/api/transactions', params: {
        transaction: {
          description: 'Uber Trip 1234',
          value: '32,90',
          date: Date.current,
          kind: 'expense',
          source: 'cash'
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transaction = Transaction.find(body['id'])

      expect(transaction.category_id).to eq(category.id)
      expect(transaction.classification_suggestions.pending.count).to eq(0)
      expect(body.dig('category', 'id')).to eq(category.id)
    end

    it 'creates a pending suggestion when no confident match exists' do
      post '/api/transactions', params: {
        transaction: {
          description: 'Loja XPTO Centro',
          value: '89,10',
          date: Date.current,
          kind: 'expense',
          source: 'cash'
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transaction = Transaction.find(body['id'])

      expect(transaction.category_id).to be_nil
      expect(transaction.classification_suggestions.pending.count).to eq(1)
      expect(body['category']).to be_nil
    end

    it 'rejects a card from another user' do
      other_user = create(:user)
      other_card = create(:card, user: other_user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Compra teste',
          value: '15,00',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: other_card.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end
  end
end
