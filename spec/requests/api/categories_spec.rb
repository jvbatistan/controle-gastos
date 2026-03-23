require 'rails_helper'

RSpec.describe 'Api::Categories', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /api/categories' do
    it 'returns the current user categories ordered by name' do
      create(:category, user: user, name: 'Transporte')
      create(:category, user: user, name: 'Alimentação')
      create(:category, user: create(:user), name: 'Outra')

      get '/api/categories'

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.map { |item| item['name'] }).to eq(['Alimentação', 'Transporte'])
    end
  end

  describe 'POST /api/categories' do
    it 'creates a category for the current user' do
      post '/api/categories', params: {
        category: {
          name: 'Lazer',
          icon: 'gamepad-2'
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      category = user.categories.find(body['id'])
      expect(category.name).to eq('Lazer')
      expect(category.icon).to eq('gamepad-2')
      expect(body['name']).to eq('Lazer')
      expect(body['icon']).to eq('gamepad-2')
    end

    it 'rejects duplicate category names for the same user' do
      create(:category, user: user, name: 'Lazer')

      post '/api/categories', params: {
        category: {
          name: 'Lazer'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end
  end

  describe 'PATCH /api/categories/:id' do
    it 'updates a category from the current user' do
      category = create(:category, user: user, name: 'Lazer')

      patch "/api/categories/#{category.id}", params: {
        category: {
          name: 'Supermercado',
          icon: 'shopping-cart'
        }
      }

      expect(response).to have_http_status(:ok)

      category.reload
      body = JSON.parse(response.body)
      expect(category.name).to eq('Supermercado')
      expect(category.icon).to eq('shopping-cart')
      expect(body['name']).to eq('Supermercado')
    end

    it 'does not update another user category' do
      other_category = create(:category, user: create(:user))

      patch "/api/categories/#{other_category.id}", params: {
        category: {
          name: 'Tentativa'
        }
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/categories/:id' do
    it 'deletes a category that is not in use' do
      category = create(:category, user: user)

      delete "/api/categories/#{category.id}"

      expect(response).to have_http_status(:no_content)
      expect(Category.exists?(category.id)).to eq(false)
    end

    it 'rejects deletion when the category is in use by transactions' do
      category = create(:category, user: user)
      create(:transaction, user: user, category: category)

      delete "/api/categories/#{category.id}"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('Categoria em uso e não pode ser removida')
      expect(Category.exists?(category.id)).to eq(true)
    end
  end
end
