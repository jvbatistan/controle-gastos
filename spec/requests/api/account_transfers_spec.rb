require "rails_helper"

RSpec.describe "Api::AccountTransfers", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  def request_metrics
    selects = 0
    callback = ->(_name, _start, _finish, _id, payload) { selects += 1 if !payload[:cached] && payload[:sql].to_s.match?(/\A\s*SELECT/i) }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
    { selects: selects, duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000).round(1), payload_bytes: response.body.bytesize }
  end

  describe "GET /api/account_transfers" do
    it "paginates with ten records by default and caps per_page" do
      from_account = create(:account, user: user)
      to_account = create(:account, user: user)
      transfers = 12.times.map { |index| create(:account_transfer, user: user, from_account: from_account, to_account: to_account, transferred_on: Date.new(2026, 7, 18), description: "Transfer #{index}") }

      get "/api/account_transfers", params: { page: 2 }
      body = JSON.parse(response.body)
      expect(body['pagination']).to eq('page' => 2, 'per_page' => 10, 'total_count' => 12, 'total_pages' => 2)
      expect(body['transfers'].map { |item| item['id'] }).to eq(transfers.first(2).reverse.map(&:id))

      get "/api/account_transfers", params: { page: 0, per_page: 999 }
      expect(JSON.parse(response.body)['pagination']).to include('page' => 1, 'per_page' => 100)

      metrics = request_metrics { get "/api/account_transfers", params: { page: 1, per_page: 10 } }
      warn("PERFORMANCE_1D_TRANSFERS #{metrics.inspect}") if ENV['PERFORMANCE_1D_METRICS'] == '1'
    end
    it "returns only transfers from the current user ordered by transferred_on and created_at" do
      from_account = create(:account, user: user, name: "Nubank")
      to_account = create(:account, user: user, name: "Poupança")
      older = create(:account_transfer, user: user, from_account: from_account, to_account: to_account, transferred_on: Date.new(2026, 7, 18))
      newer = create(:account_transfer, user: user, from_account: from_account, to_account: to_account, transferred_on: Date.new(2026, 7, 18))
      previous_day = create(:account_transfer, user: user, from_account: from_account, to_account: to_account, transferred_on: Date.new(2026, 7, 17))
      other_user = create(:user)
      create(:account_transfer, user: other_user)

      older.update_column(:created_at, Time.zone.parse("2026-07-18 10:00:00"))
      newer.update_column(:created_at, Time.zone.parse("2026-07-18 11:00:00"))

      get "/api/account_transfers"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body['transfers'].map { |item| item["id"] }).to eq([newer.id, older.id, previous_day.id])
      expect(body['transfers'].first).to include(
        "from_account" => { "id" => from_account.id, "name" => "Nubank" },
        "to_account" => { "id" => to_account.id, "name" => "Poupança" },
        "status" => "completed"
      )
    end

    it "includes completed and reversed transfers by default" do
      completed = create(:account_transfer, user: user, status: :completed)
      reversed = create(:account_transfer, user: user, status: :reversed)

      get "/api/account_transfers"

      body = JSON.parse(response.body)
      expect(body['transfers'].map { |item| item["id"] }).to contain_exactly(completed.id, reversed.id)
    end

    it "filters transfers by status" do
      completed = create(:account_transfer, user: user, status: :completed)
      create(:account_transfer, user: user, status: :reversed)

      get "/api/account_transfers", params: { status: "completed" }

      body = JSON.parse(response.body)
      expect(body['transfers'].map { |item| item["id"] }).to eq([completed.id])
    end

    it "rejects invalid status filter" do
      get "/api/account_transfers", params: { status: "deleted" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Status inválido.")
    end

    it "filters transfers by origin or destination account" do
      account = create(:account, user: user)
      other_account = create(:account, user: user)
      third_account = create(:account, user: user)
      outgoing = create(:account_transfer, user: user, from_account: account, to_account: other_account)
      incoming = create(:account_transfer, user: user, from_account: other_account, to_account: account)
      create(:account_transfer, user: user, from_account: other_account, to_account: third_account)

      get "/api/account_transfers", params: { account_id: account.id }

      body = JSON.parse(response.body)
      expect(body['transfers'].map { |item| item["id"] }).to contain_exactly(outgoing.id, incoming.id)
    end

    it "returns an empty list for account filter from another user without leaking it" do
      create(:account_transfer, user: user)
      other_account = create(:account, user: create(:user))

      get "/api/account_transfers", params: { account_id: other_account.id }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq('transfers' => [], 'pagination' => { 'page' => 1, 'per_page' => 10, 'total_count' => 0, 'total_pages' => 0 })
    end
  end

  describe "GET /api/account_transfers/:id" do
    it "returns a transfer from the current user" do
      transfer = create(:account_transfer, user: user, amount: 200, transferred_on: Date.new(2026, 7, 18), description: "Reserva", note: "Mês")

      get "/api/account_transfers/#{transfer.id}"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body).to include(
        "id" => transfer.id,
        "amount" => "200.0",
        "transferred_on" => "2026-07-18",
        "description" => "Reserva",
        "note" => "Mês",
        "status" => "completed"
      )
    end

    it "does not reveal another user transfer" do
      other_transfer = create(:account_transfer, user: create(:user))

      get "/api/account_transfers/#{other_transfer.id}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Not found")
    end

    it "returns not found for a missing transfer" do
      get "/api/account_transfers/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/account_transfers" do
    it "creates a completed transfer between active accounts from the current user" do
      from_account = create(:account, user: user, initial_balance: 1000)
      to_account = create(:account, user: user, initial_balance: 500)

      expect do
        post "/api/account_transfers", params: {
          account_transfer: {
            from_account_id: from_account.id,
            to_account_id: to_account.id,
            amount: "200.00",
            transferred_on: "2026-07-18",
            description: "Reserva do mês",
            note: "Movido para poupança",
            status: "reversed"
          }
        }
      end.to change(AccountTransfer, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(Transaction.count).to eq(0)

      transfer = AccountTransfer.last
      expect(transfer.user).to eq(user)
      expect(transfer.from_account).to eq(from_account)
      expect(transfer.to_account).to eq(to_account)
      expect(transfer.status).to eq("completed")

      body = JSON.parse(response.body)
      expect(body).to include(
        "id" => transfer.id,
        "amount" => "200.0",
        "status" => "completed"
      )
      expect(body["from_account"]).to include("id" => from_account.id)
      expect(body["to_account"]).to include("id" => to_account.id)
      expect(Accounts::BalanceCalculator.call(from_account)).to eq(800.to_d)
      expect(Accounts::BalanceCalculator.call(to_account)).to eq(700.to_d)
      expect(total_balance(from_account, to_account)).to eq(1500.to_d)
    end

    it "rejects a transfer that exceeds the origin account balance without creating a movement" do
      from_account = create(:account, user: user, initial_balance: 50)
      to_account = create(:account, user: user, initial_balance: 0)

      expect do
        post "/api/account_transfers", params: {
          account_transfer: {
            from_account_id: from_account.id,
            to_account_id: to_account.id,
            amount: "200.00",
            transferred_on: "2026-07-18"
          }
        }
      end.not_to change(AccountTransfer, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).fetch('error')).to include('Saldo insuficiente')
      expect(Accounts::BalanceCalculator.call(from_account)).to eq(50.to_d)
      expect(Accounts::BalanceCalculator.call(to_account)).to eq(0.to_d)
    end

    it "does not change dashboard metrics" do
      from_account = create(:account, user: user, initial_balance: 200)
      to_account = create(:account, user: user)
      before_summary = dashboard_summary(month: 7, year: 2026)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:created)
      expect(dashboard_summary(month: 7, year: 2026)).to eq(before_summary)
    end

    it "rejects transfer without origin account" do
      to_account = create(:account, user: user)

      post "/api/account_transfers", params: {
        account_transfer: {
          to_account_id: to_account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Conta de origem é obrigatória.")
    end

    it "rejects transfer without destination account" do
      from_account = create(:account, user: user)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: from_account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Conta de destino é obrigatória.")
    end

    it "rejects transfer without amount" do
      from_account = create(:account, user: user)
      to_account = create(:account, user: user)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to be_present
    end

    it "rejects transfer without transferred_on" do
      from_account = create(:account, user: user)
      to_account = create(:account, user: user)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          amount: "200.00"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to be_present
    end

    it "rejects zero or negative amount" do
      from_account = create(:account, user: user)
      to_account = create(:account, user: user)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          amount: "0",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to be_present
    end

    it "rejects same origin and destination accounts" do
      account = create(:account, user: user)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: account.id,
          to_account_id: account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to be_present
    end

    it "rejects archived origin or destination accounts" do
      active_account = create(:account, user: user)
      archived_account = create(:account, user: user, archived_at: Time.current)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: archived_account.id,
          to_account_id: active_account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:not_found)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: active_account.id,
          to_account_id: archived_account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects origin or destination accounts from another user without leaking them" do
      active_account = create(:account, user: user)
      other_account = create(:account, user: create(:user))

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: other_account.id,
          to_account_id: active_account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:not_found)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: active_account.id,
          to_account_id: other_account.id,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects missing accounts without leaking them" do
      from_account = create(:account, user: user)

      post "/api/account_transfers", params: {
        account_transfer: {
          from_account_id: from_account.id,
          to_account_id: 999999,
          amount: "200.00",
          transferred_on: "2026-07-18"
        }
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/account_transfers/:id/reverse" do
    it "reverses a completed transfer and removes its effect from balances" do
      from_account = create(:account, user: user, initial_balance: 1000)
      to_account = create(:account, user: user, initial_balance: 500)
      transfer = create(:account_transfer, user: user, from_account: from_account, to_account: to_account, amount: 200)

      expect(Accounts::BalanceCalculator.call(from_account)).to eq(800.to_d)
      expect(Accounts::BalanceCalculator.call(to_account)).to eq(700.to_d)

      expect do
        patch "/api/account_transfers/#{transfer.id}/reverse"
      end.not_to change(AccountTransfer, :count)

      expect(response).to have_http_status(:ok)
      expect(Transaction.count).to eq(0)
      expect(transfer.reload.status).to eq("reversed")
      expect(Accounts::BalanceCalculator.call(from_account)).to eq(1000.to_d)
      expect(Accounts::BalanceCalculator.call(to_account)).to eq(500.to_d)
      expect(total_balance(from_account, to_account)).to eq(1500.to_d)

      body = JSON.parse(response.body)
      expect(body).to include("id" => transfer.id, "status" => "reversed")
    end

    it "is idempotent when the transfer is already reversed" do
      transfer = create(:account_transfer, user: user, status: :reversed)

      patch "/api/account_transfers/#{transfer.id}/reverse"
      first_updated_at = transfer.reload.updated_at

      patch "/api/account_transfers/#{transfer.id}/reverse"

      expect(response).to have_http_status(:ok)
      expect(transfer.reload.status).to eq("reversed")
      expect(transfer.updated_at.to_i).to eq(first_updated_at.to_i)
    end

    it "does not change dashboard metrics" do
      from_account = create(:account, user: user)
      to_account = create(:account, user: user)
      transfer = create(:account_transfer, user: user, from_account: from_account, to_account: to_account, transferred_on: Date.new(2026, 7, 18))
      before_summary = dashboard_summary(month: 7, year: 2026)

      patch "/api/account_transfers/#{transfer.id}/reverse"

      expect(response).to have_http_status(:ok)
      expect(dashboard_summary(month: 7, year: 2026)).to eq(before_summary)
    end

    it "does not reveal another user transfer" do
      other_transfer = create(:account_transfer, user: create(:user))

      patch "/api/account_transfers/#{other_transfer.id}/reverse"

      expect(response).to have_http_status(:not_found)
      expect(other_transfer.reload.status).to eq("completed")
    end
  end

  private

  def total_balance(*accounts)
    accounts.sum { |account| Accounts::BalanceCalculator.call(account) }
  end

  def dashboard_summary(month:, year:)
    get "/api/dashboard", params: { month: month, year: year }
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)["summary"]
  end
end
