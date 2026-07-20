require 'rails_helper'

RSpec.describe 'Api::AccountStatements', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /api/accounts/:id/statement' do
    it 'returns the account statement contract for the current user' do
      account = create(:account, user: user, name: 'Nubank', initial_balance: 250, initial_balance_date: Date.new(2026, 7, 1))
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 1_000, date: Date.new(2026, 7, 5), description: 'Salário')
      create(:transaction, user: user, kind: :expense, source: :cash, account: account, card: nil, value: 100, date: Date.new(2026, 7, 6), description: 'Mercado')

      get "/api/accounts/#{account.id}/statement"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.keys).to contain_exactly('account', 'period', 'filters', 'summary', 'pagination', 'items')
      expect(body['account']).to include(
        'id' => account.id,
        'name' => 'Nubank',
        'current_balance' => '1150.0'
      )
      expect(body['summary']).to include(
        'credits_total' => '1250.0',
        'debits_total' => '100.0',
        'net_total' => '1150.0'
      )
      expect(body['pagination']).to include(
        'page' => 1,
        'per_page' => 25,
        'total_count' => 3,
        'total_pages' => 1
      )
      expect(body['items'].map { |item| item['movement_type'] }).to contain_exactly('initial_balance', 'income', 'expense')
    end

    it 'applies filters and pagination from query params' do
      account = create(:account, user: user, initial_balance: 100, initial_balance_date: Date.new(2026, 7, 1))
      create(:transaction, user: user, kind: :income, source: :bank, account: account, card: nil, value: 10, date: Date.new(2026, 7, 5))
      create(:transaction, user: user, kind: :income, source: :cash, account: account, card: nil, value: 20, date: Date.new(2026, 7, 6))
      create(:transaction, user: user, kind: :expense, source: :bank, account: account, card: nil, value: 5, date: Date.new(2026, 7, 6))

      get "/api/accounts/#{account.id}/statement", params: {
        start_date: '2026-07-05',
        end_date: '2026-07-06',
        movement_type: 'income',
        direction: 'credit',
        page: 2,
        per_page: 1
      }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body['period']).to include('start_date' => '2026-07-05', 'end_date' => '2026-07-06')
      expect(body['filters']).to include('movement_type' => 'income', 'direction' => 'credit')
      expect(body['summary']).to include('credits_total' => '30.0', 'debits_total' => '0.0', 'net_total' => '30.0')
      expect(body['pagination']).to include('page' => 2, 'per_page' => 1, 'total_count' => 2, 'total_pages' => 2)
      expect(body['items'].size).to eq(1)
      expect(body['items'].first['amount']).to eq('10.0')
    end

    it 'does not reveal another user account' do
      other_user = create(:user)
      other_account = create(:account, user: other_user)

      get "/api/accounts/#{other_account.id}/statement"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns a safe error for invalid filters' do
      account = create(:account, user: user)

      get "/api/accounts/#{account.id}/statement", params: { movement_type: 'pix' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('Tipo de movimento inválido.')
    end

    it 'can return the statement for an archived account' do
      account = create(:account, user: user, initial_balance: 100)
      account.archive!

      get "/api/accounts/#{account.id}/statement"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['account']['archived_at']).to be_present
    end
  end
end
