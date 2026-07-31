require "rails_helper"
require "csv"

RSpec.describe "Api::AccountStatementExports", type: :request do
  let(:user) { create(:user) }
  let(:account) do
    create(
      :account,
      user: user,
      name: "Conta Principal",
      initial_balance: 100,
      initial_balance_date: Date.new(2026, 7, 1)
    )
  end

  before do
    sign_in user
  end

  it "downloads UTF-8 CSV with BOM, attachment headers and an account filename" do
    get "/api/accounts/#{account.id}/statement/export_csv"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.content_type).to include("charset=utf-8")
    expect(response.headers["Content-Disposition"]).to include("attachment")
    expect(response.headers["Content-Disposition"]).to include("finch-extrato-conta-principal-#{Time.zone.today.iso8601}.csv")
    expect(response.body).to start_with("\uFEFF")
  end

  it "uses statement filters and ignores page and per_page" do
    create(:transaction, user: user, account: account, kind: :income, source: :bank, card: nil, value: 10, date: Date.new(2026, 7, 5), description: "Primeira")
    create(:transaction, user: user, account: account, kind: :income, source: :bank, card: nil, value: 20, date: Date.new(2026, 7, 6), description: "Segunda")
    create(:transaction, user: user, account: account, kind: :expense, source: :bank, card: nil, value: 5, date: Date.new(2026, 7, 6), description: "Saída")

    get "/api/accounts/#{account.id}/statement/export_csv", params: {
      start_date: "2026-07-05",
      end_date: "2026-07-06",
      movement_type: "income",
      direction: "credit",
      page: 2,
      per_page: 1
    }

    parsed = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ";")
    expect(response).to have_http_status(:ok)
    expect(parsed).to include(
      ["Filtros", "Tipo: Entrada | Direção: Entrada"],
      ["Entradas", "30.00"]
    )
    expect(parsed.flatten).to include("PRIMEIRA", "SEGUNDA")
    expect(parsed.flatten).not_to include("SAÍDA")
  end

  it "does not reveal another user's account" do
    other_account = create(:account, user: create(:user))

    get "/api/accounts/#{other_account.id}/statement/export_csv"

    expect(response).to have_http_status(:not_found)
  end

  it "returns validation errors for invalid statement params" do
    get "/api/accounts/#{account.id}/statement/export_csv", params: { direction: "sideways" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["error"]).to eq("Direção inválida.")
  end
end
