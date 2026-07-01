require 'rails_helper'

RSpec.describe 'Api::Accounts', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /api/accounts' do
    it 'returns only active accounts from the current user ordered by name' do
      create(:account, user: user, name: 'Nubank')
      create(:account, user: user, name: 'Carteira', kind: :wallet, archived_at: Time.current)
      create(:account, user: user, name: 'Inter')
      create(:account, user: create(:user), name: 'Outra')

      get '/api/accounts'

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.map { |item| item['name'] }).to eq(%w[Inter Nubank])
      expect(body.first.keys).to include('initial_balance', 'initial_balance_date', 'current_balance', 'archived_at')
    end

    it 'returns archived accounts from the current user when requested' do
      create(:account, user: user, name: 'Ativa')
      create(:account, user: user, name: 'Arquivada', archived_at: Time.current)
      create(:account, user: create(:user), name: 'Outra arquivada', archived_at: Time.current)

      get '/api/accounts', params: { archived: true }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.map { |item| item['name'] }).to eq(['Arquivada'])
      expect(body.first['archived_at']).to be_present
    end
  end

  describe 'GET /api/accounts/:id' do
    it 'returns an account from the current user' do
      account = create(:account, user: user, name: 'Nubank', initial_balance: 2000, initial_balance_date: Date.new(2026, 7, 1))

      get "/api/accounts/#{account.id}"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body).to include(
        'id' => account.id,
        'name' => 'Nubank',
        'kind' => 'checking',
        'initial_balance' => '2000.0',
        'initial_balance_date' => '2026-07-01',
        'current_balance' => '2000.0'
      )
    end

    it 'does not reveal another user account' do
      other_account = create(:account, user: create(:user))

      get "/api/accounts/#{other_account.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/accounts' do
    it 'creates a valid account for the current user' do
      post '/api/accounts', params: {
        account: {
          name: 'Nubank',
          kind: 'checking',
          initial_balance: 2000,
          initial_balance_date: '2026-07-01'
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      account = user.accounts.find(body['id'])
      expect(account.name).to eq('Nubank')
      expect(account.kind).to eq('checking')
      expect(account.initial_balance).to eq(2000.to_d)
      expect(account.initial_balance_date).to eq(Date.new(2026, 7, 1))
      expect(body['current_balance']).to eq('2000.0')
    end

    it 'uses default initial balance when it is omitted' do
      post '/api/accounts', params: {
        account: {
          name: 'Carteira',
          kind: 'wallet',
          initial_balance_date: '2026-07-01'
        }
      }

      expect(response).to have_http_status(:created)

      account = user.accounts.find(JSON.parse(response.body)['id'])
      expect(account.initial_balance).to eq(0.to_d)
    end

    it 'rejects account without name' do
      post '/api/accounts', params: {
        account: {
          name: '',
          kind: 'checking',
          initial_balance_date: '2026-07-01'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end

    it 'rejects account without kind' do
      post '/api/accounts', params: {
        account: {
          name: 'Sem tipo',
          initial_balance_date: '2026-07-01'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end

    it 'rejects invalid kind' do
      post '/api/accounts', params: {
        account: {
          name: 'Investimento',
          kind: 'investment',
          initial_balance_date: '2026-07-01'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end

    it 'requires initial balance date' do
      post '/api/accounts', params: {
        account: {
          name: 'Sem data',
          kind: 'checking',
          initial_balance: 0
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end
  end

  describe 'PATCH /api/accounts/:id' do
    it 'updates an account from the current user' do
      account = create(:account, user: user, name: 'Nubank')

      patch "/api/accounts/#{account.id}", params: {
        account: {
          name: 'Inter',
          kind: 'savings',
          initial_balance: 500,
          initial_balance_date: '2026-07-02'
        }
      }

      expect(response).to have_http_status(:ok)

      account.reload
      expect(account.name).to eq('Inter')
      expect(account.kind).to eq('savings')
      expect(account.initial_balance).to eq(500.to_d)
      expect(account.initial_balance_date).to eq(Date.new(2026, 7, 2))
    end

    it 'does not update another user account' do
      other_account = create(:account, user: create(:user))

      patch "/api/accounts/#{other_account.id}", params: {
        account: { name: 'Tentativa' }
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/accounts/:id' do
    it 'archives an account without deleting it' do
      account = create(:account, user: user)

      delete "/api/accounts/#{account.id}"

      expect(response).to have_http_status(:ok)
      expect(account.reload.archived_at).to be_present
      expect(Account.exists?(account.id)).to eq(true)
      expect(JSON.parse(response.body)['archived_at']).to be_present
    end

    it 'does not archive another user account' do
      other_account = create(:account, user: create(:user))

      delete "/api/accounts/#{other_account.id}"

      expect(response).to have_http_status(:not_found)
      expect(other_account.reload.archived_at).to be_nil
    end
  end

  describe 'PATCH /api/accounts/:id/restore' do
    it 'restores an archived account' do
      account = create(:account, user: user, archived_at: Time.current)

      patch "/api/accounts/#{account.id}/restore"

      expect(response).to have_http_status(:ok)
      expect(account.reload.archived_at).to be_nil
      expect(JSON.parse(response.body)['archived_at']).to be_nil
    end

    it 'does not restore another user account' do
      other_account = create(:account, user: create(:user), archived_at: Time.current)

      patch "/api/accounts/#{other_account.id}/restore"

      expect(response).to have_http_status(:not_found)
      expect(other_account.reload.archived_at).to be_present
    end
  end
end
