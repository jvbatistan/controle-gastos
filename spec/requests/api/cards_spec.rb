require 'rails_helper'

RSpec.describe 'Api::Cards', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /api/cards' do
    it 'returns the current user cards ordered by name' do
      create(:card, user: user, name: 'Visa Platinum')
      create(:card, user: user, name: 'Amex Gold')
      create(:card, user: create(:user), name: 'Outro')

      get '/api/cards'

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.map { |item| item['name'] }).to eq(['AMEX GOLD', 'VISA PLATINUM'])
      expect(body.first['due_day']).to be_present
      expect(body.first['closing_day']).to be_present
    end
  end

  describe 'POST /api/cards' do
    it 'creates a card for the current user' do
      post '/api/cards', params: {
        card: {
          name: 'Nubank',
          due_day: 15,
          closing_day: 8,
          limit: 4500
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      card = user.cards.find(body['id'])
      expect(card.name).to eq('NUBANK')
      expect(card.due_day).to eq(15)
      expect(card.closing_day).to eq(8)
      expect(card.limit).to eq(4500)
    end

    it 'rejects invalid cycle days' do
      post '/api/cards', params: {
        card: {
          name: 'Cartao',
          due_day: 32,
          closing_day: 0
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end
  end

  describe 'PATCH /api/cards/:id' do
    it 'updates a card from the current user' do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)

      patch "/api/cards/#{card.id}", params: {
        card: {
          name: 'Inter',
          due_day: 10,
          closing_day: 3,
          limit: 9000
        }
      }

      expect(response).to have_http_status(:ok)

      card.reload
      expect(card.name).to eq('INTER')
      expect(card.due_day).to eq(10)
      expect(card.closing_day).to eq(3)
      expect(card.limit).to eq(9000)
    end

    it 'does not update another user card' do
      other_card = create(:card, user: create(:user))

      patch "/api/cards/#{other_card.id}", params: {
        card: { name: 'Tentativa' }
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/cards/:id' do
    it 'deletes a card that is not in use' do
      card = create(:card, user: user)

      delete "/api/cards/#{card.id}"

      expect(response).to have_http_status(:no_content)
      expect(Card.exists?(card.id)).to eq(false)
    end

    it 'rejects deletion when the card is in use by transactions' do
      card = create(:card, user: user)
      create(:transaction, user: user, card: card, source: :card)

      delete "/api/cards/#{card.id}"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('Cartão em uso e não pode ser removido')
      expect(Card.exists?(card.id)).to eq(true)
    end
  end
end
