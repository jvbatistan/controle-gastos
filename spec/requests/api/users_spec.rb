require 'rails_helper'

RSpec.describe 'Api::Users', type: :request do
  describe 'POST /api/register' do
    it 'registers a user and signs them in' do
      post '/api/register', params: {
        user: {
          name: 'Joao Vitor',
          email: 'joao@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      user = User.find_by(email: 'joao@example.com')

      expect(user).to be_present
      expect(body['name']).to eq('Joao Vitor')
      expect(body['email']).to eq('joao@example.com')
      expect(body['active']).to eq(true)
    end

    it 'blocks registration when the user limit is reached' do
      create_list(:user, 2)

      post '/api/register', params: {
        user: {
          name: 'Maria',
          email: 'maria@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Limite máximo de usuários atingido')
    end
  end

  describe 'GET /api/me' do
    it 'returns the current user profile' do
      user = create(:user, name: 'Joao')
      sign_in user

      get '/api/me'

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body['id']).to eq(user.id)
      expect(body['name']).to eq('Joao')
      expect(body['email']).to eq(user.email)
      expect(body['active']).to eq(true)
    end
  end

  describe 'PATCH /api/me' do
    it 'updates the current user profile' do
      user = create(:user, name: 'Joao')
      sign_in user

      patch '/api/me', params: {
        user: {
          name: 'Joao Atualizado',
          email: 'novo@example.com'
        }
      }

      expect(response).to have_http_status(:ok)

      user.reload
      body = JSON.parse(response.body)
      expect(user.name).to eq('Joao Atualizado')
      expect(user.email).to eq('novo@example.com')
      expect(body['name']).to eq('Joao Atualizado')
    end
  end

  describe 'POST /api/login' do
    it 'does not authenticate inactive users' do
      user = create(:user, active: false, email: 'inactive@example.com', password: 'password123', password_confirmation: 'password123')

      post '/api/login', params: {
        email: user.email,
        password: 'password123'
      }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('Credenciais inválidas')
    end
  end
end
