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
      expect(body["loose_expenses"]["transactions_count"]).to eq(1)
      expect(body["loose_expenses"]["total_amount"]).to eq("80.0")
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
end
