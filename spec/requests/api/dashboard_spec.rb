require "rails_helper"

RSpec.describe "Api::Dashboard", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /api/dashboard" do
    it "returns real expense metrics for the selected period" do
      food = create(:category, user: user, name: "Alimentação")
      travel = create(:category, user: user, name: "Transporte")
      card = create(:card, user: user, name: "Nubank", due_day: 15, closing_day: 8)

      create(
        :transaction,
        user: user,
        category: food,
        card: nil,
        source: :cash,
        date: Date.new(2026, 4, 10),
        value: 80,
        paid: false,
        description: "Mercado"
      )
      create(
        :transaction,
        user: user,
        category: travel,
        card: card,
        source: :card,
        date: Date.new(2026, 4, 7),
        value: 120,
        paid: true,
        description: "Uber"
      )
      create(
        :transaction,
        user: user,
        category: nil,
        card: card,
        source: :card,
        date: Date.new(2026, 4, 6),
        value: 60,
        paid: false,
        description: "Farmacia"
      )
      create(
        :transaction,
        user: user,
        category: food,
        source: :cash,
        card: nil,
        date: Date.new(2026, 3, 10),
        value: 50,
        paid: false,
        description: "Mes anterior"
      )

      get "/api/dashboard", params: { month: 4, year: 2026 }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body["period"]).to include("month" => 4, "year" => 2026)
      expect(body["summary"]).to eq(
        "expenses_total" => "260.0",
        "open_total" => "140.0",
        "paid_total" => "120.0",
        "transactions_count" => 3
      )

      by_card = body["by_card"]
      expect(by_card.map { |entry| entry["name"] }).to eq(["NUBANK", "Sem cartão"])
      expect(by_card.first["total_amount"]).to eq("180.0")
      expect(by_card.first["open_amount"]).to eq("60.0")
      expect(by_card.first["paid_amount"]).to eq("120.0")

      by_category = body["by_category"]
      expect(by_category.map { |entry| entry["name"] }).to include("Alimentação", "Transporte", "Sem categoria")

      expect(body["recent_expenses"].size).to be <= 8
      expect(body["recent_expenses"].first.keys).to include("description", "value", "category", "card")

      expect(body["statements"].size).to eq(1)
      expect(body["statements"].first.dig("card", "name")).to eq("NUBANK")
      expect(body["statements"].first["total_amount"]).to eq("180.0")
    end
  end
end
