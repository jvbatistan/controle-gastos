require "rails_helper"

RSpec.describe "Api::Payments", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /api/payments" do
    it "returns statements and loose expenses for the selected period" do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)
      create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 7), value: 120)
      create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 10), value: 80)
      create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 4, 10), value: 50)

      get "/api/payments", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["period"]).to eq({ "month" => 3, "year" => 2026 })
      expect(body["statements"].size).to eq(1)
      expect(body["statements"].first.dig("card", "name")).to eq("NUBANK")
      expect(body["statements"].first["ignored_at"]).to eq(nil)
      expect(body["loose_expenses"]["transactions_count"]).to eq(1)
      expect(body["loose_expenses"]["total_amount"]).to eq("80.0")
      expect(body["ignored_payments"]["statements_count"]).to eq(0)
      expect(body["ignored_payments"]["loose_expenses"]["transactions_count"]).to eq(0)
    end

    it "ignores archived transactions in statements and loose expenses" do
      card = create(:card, user: user, name: "Nubank", due_day: 15, closing_day: 8)
      create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 7), value: 120, archived_at: Time.current)
      create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 10), value: 80, archived_at: Time.current)

      get "/api/payments", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["statements"].size).to eq(1)
      expect(body["statements"].first["total_amount"]).to eq("0.0")
      expect(body["statements"].first["remaining_amount"]).to eq("0.0")
      expect(body["statements"].first["transactions_count"]).to eq(0)
      expect(body["loose_expenses"]["transactions_count"]).to eq(0)
      expect(body["loose_expenses"]["total_amount"]).to eq("0.0")
    end

    it "ignores loose expenses removed from the payment flow" do
      create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 10), value: 80, payment_ignored_at: Time.current)
      create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 11), value: 50)

      get "/api/payments", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["loose_expenses"]["transactions_count"]).to eq(1)
      expect(body["loose_expenses"]["total_amount"]).to eq("50.0")
      expect(body["loose_expenses"]["transactions"].map { |transaction| transaction["value"] }).to eq(["50.0"])
      expect(body["ignored_payments"]["loose_expenses"]["transactions_count"]).to eq(1)
      expect(body["ignored_payments"]["loose_expenses"]["total_amount"]).to eq("80.0")
      expect(body["ignored_payments"]["loose_expenses"]["transactions"].first["payment_ignored_at"]).to be_present
    end

    it "returns ignored statements for the selected period" do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)
      create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 7), value: 120, paid: false)
      statement = card.sync_statement!(3, 2026)
      statement.ignore_for_payment!

      get "/api/payments", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["statements"]).to eq([])
      expect(body["ignored_payments"]["statements_count"]).to eq(1)
      expect(body["ignored_payments"]["statements_total_amount"]).to eq("120.0")
      expect(body["ignored_payments"]["statements"].first.dig("card", "name")).to eq("NUBANK")
      expect(body["ignored_payments"]["statements"].first["ignored_at"]).to be_present
    end
  end

  describe "POST /api/payments/card_statements/:id/pay" do
    it "pays the remaining amount of the statement and marks its transactions as paid" do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)
      transaction = create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 7), value: 120, paid: false)
      statement = card.sync_statement!(3, 2026)

      post "/api/payments/card_statements/#{statement.id}/pay"

      expect(response).to have_http_status(:ok)

      transaction.reload
      statement.reload
      body = JSON.parse(response.body)
      expect(statement.paid?).to eq(true)
      expect(transaction.paid).to eq(true)
      expect(body["remaining_amount"]).to eq("0.0")
    end
  end

  describe "POST /api/payments/card_statements/:id/ignore" do
    it "marks a statement as ignored for the selected period" do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)
      create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 7), value: 120, paid: false)
      statement = card.sync_statement!(3, 2026)

      post "/api/payments/card_statements/#{statement.id}/ignore", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      statement.reload
      body = JSON.parse(response.body)
      expect(statement.ignored_at).to be_present
      expect(body["ignored_at"]).to be_present
    end

    it "returns not found when the statement is outside the selected period" do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)
      create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 4, 7), value: 120, paid: false)
      statement = card.sync_statement!(4, 2026)

      post "/api/payments/card_statements/#{statement.id}/ignore", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:not_found)

      statement.reload
      body = JSON.parse(response.body)
      expect(statement.ignored_at).to eq(nil)
      expect(body["error"]).to eq("Fatura não encontrada para o período selecionado.")
    end

    it "hides ignored statements from the payments overview" do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)
      create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 7), value: 120, paid: false)
      statement = card.sync_statement!(3, 2026)
      statement.ignore_for_payment!

      get "/api/payments", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["statements"]).to eq([])
    end
  end

  describe "POST /api/payments/loose_expenses/pay" do
    it "marks the loose expenses of the period as paid" do
      transaction = create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 3, 10), value: 80, paid: false)
      create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 4, 10), value: 50, paid: false)

      post "/api/payments/loose_expenses/pay", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      transaction.reload
      body = JSON.parse(response.body)
      expect(transaction.paid).to eq(true)
      expect(body["paid_transactions_count"]).to eq(1)
      expect(body["total_amount"]).to eq("80.0")
    end
  end

  describe "POST /api/payments/loose_expenses/:id/pay" do
    it "marks a single loose expense as paid for the selected period" do
      transaction = create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 3, 10), value: 80, paid: false, description: "Uber")
      create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 3, 11), value: 50, paid: false)

      post "/api/payments/loose_expenses/#{transaction.id}/pay", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      transaction.reload
      body = JSON.parse(response.body)
      expect(transaction.paid).to eq(true)
      expect(body["id"]).to eq(transaction.id)
      expect(body["description"]).to eq("UBER")
      expect(body["paid"]).to eq(true)
    end

    it "returns not found when the expense is outside the selected period" do
      transaction = create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 4, 10), value: 80, paid: false)

      post "/api/payments/loose_expenses/#{transaction.id}/pay", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:not_found)

      transaction.reload
      body = JSON.parse(response.body)
      expect(transaction.paid).to eq(false)
      expect(body["error"]).to eq("Despesa avulsa não encontrada para o período selecionado.")
    end
  end

  describe "POST /api/payments/loose_expenses/:id/ignore" do
    it "removes a single loose expense from the payment flow for the selected period" do
      transaction = create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 3, 10), value: 80, paid: false, description: "Uber")
      create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 3, 11), value: 50, paid: false)

      post "/api/payments/loose_expenses/#{transaction.id}/ignore", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      transaction.reload
      body = JSON.parse(response.body)
      expect(transaction.paid).to eq(false)
      expect(transaction.payment_ignored_at).to be_present
      expect(body["id"]).to eq(transaction.id)
      expect(body["payment_ignored_at"]).to be_present
    end

    it "returns not found when the expense is outside the selected period" do
      transaction = create(:transaction, user: user, card: nil, source: :bank, date: Date.new(2026, 4, 10), value: 80, paid: false)

      post "/api/payments/loose_expenses/#{transaction.id}/ignore", params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:not_found)

      transaction.reload
      body = JSON.parse(response.body)
      expect(transaction.payment_ignored_at).to eq(nil)
      expect(body["error"]).to eq("Despesa avulsa não encontrada para o período selecionado.")
    end
  end
end
