require 'rails_helper'

RSpec.describe 'Api::Transactions', type: :request do
  describe 'POST /api/transactions' do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it 'auto-classifica quando encontra um alias exato' do
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
      tx = Transaction.find(body['id'])

      expect(tx.category_id).to eq(category.id)
      expect(body.dig('classification', 'status')).to eq('classified')
      expect(body.dig('classification', 'category', 'id')).to eq(category.id)
      expect(body.dig('classification', 'suggestion')).to be_nil
    end

    it 'cria uma sugestao pendente quando nao encontra match confiavel' do
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
      tx = Transaction.find(body['id'])

      expect(tx.category_id).to be_nil
      expect(tx.classification_suggestions.pending.count).to eq(1)
      expect(body.dig('classification', 'status')).to eq('suggestion_pending')
      expect(body.dig('classification', 'suggestion', 'id')).to be_present
    end
  end

  describe 'PATCH /api/transactions/:id' do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it 'reprocessa a classificacao quando a descricao muda' do
      category = create(:category, user: user, name: 'Transporte')
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'UBER',
        category: category,
        confidence: 1.0,
        source: :user_override
      )

      transaction = user.transactions.create!(
        description: 'Loja XPTO Centro',
        value: 50,
        date: Date.current,
        kind: :expense,
        source: :cash
      )

      expect(transaction.classification_suggestions.pending.count).to eq(1)

      patch "/api/transactions/#{transaction.id}", params: {
        transaction: {
          description: 'Uber Trip 1234'
        }
      }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      transaction.reload

      expect(transaction.category_id).to eq(category.id)
      expect(transaction.classification_suggestions.pending.count).to eq(0)
      expect(body.dig('classification', 'status')).to eq('classified')
      expect(body.dig('classification', 'suggestion')).to be_nil
    end
  end
end
