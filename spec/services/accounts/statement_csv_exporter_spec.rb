require "rails_helper"
require "csv"

RSpec.describe Accounts::StatementCsvExporter do
  let(:user) { create(:user) }
  let(:account) do
    create(
      :account,
      user: user,
      name: "Conta São João / Principal",
      initial_balance: 1_000,
      initial_balance_date: Date.new(2026, 7, 1)
    )
  end

  def export(params: {})
    result = Accounts::StatementBuilder.call(account: account, params: params, paginate: false)
    described_class.call(result)
  end

  def rows(csv)
    CSV.parse(csv.delete_prefix("\uFEFF"), col_sep: ";")
  end

  it "exports the documentary header, filters, balances, summary and stable decimal values" do
    category = create(:category, user: user, name: "Salário")
    create(
      :transaction,
      user: user,
      account: account,
      category: category,
      kind: :income,
      source: :bank,
      card: nil,
      value: 250.75,
      date: Date.new(2026, 7, 5),
      description: "Salário"
    )

    csv = export(params: {
      start_date: "2026-07-01",
      end_date: "2026-07-31",
      movement_type: "income",
      direction: "credit"
    })
    parsed = rows(csv)

    expect(csv.encoding).to eq(Encoding::UTF_8)
    expect(csv).to start_with("\uFEFF")
    expect(csv).to include(";")
    expect(parsed).to include(
      ["Finch"],
      ["Extrato por Account"],
      ["Conta", "Conta São João / Principal"],
      ["Tipo", "Conta corrente"],
      ["Status", "Ativa"],
      ["Período", "2026-07-01 a 2026-07-31"],
      ["Filtros", "Tipo: Entrada | Direção: Entrada"],
      ["Saldo de abertura", "0.00"],
      ["Entradas", "250.75"],
      ["Saídas", "0.00"],
      ["Variação líquida", "250.75"],
      ["Saldo de fechamento", "1250.75"],
      described_class::ITEM_HEADERS,
      ["2026-07-05", "Entrada", "Entrada", "SALÁRIO", "Salário", "Banco", "", "250.75"]
    )
    expect(csv).not_to include("R$")
  end

  it "exports transfers and card statement payments without querying or recalculating them" do
    savings = create(:account, user: user, name: "Reserva")
    create(
      :account_transfer,
      user: user,
      from_account: account,
      to_account: savings,
      amount: 125.5,
      transferred_on: Date.new(2026, 7, 8),
      description: "Guardar"
    )
    card = create(:card, user: user, name: "NUBANK")
    statement = create(:card_statement, card: card, billing_statement: Date.new(2026, 7, 1))
    create(
      :card_statement_payment,
      card_statement: statement,
      account: account,
      amount: 300,
      paid_at: Time.zone.local(2026, 7, 9, 12),
      description: "Pagamento"
    )

    parsed = rows(export(params: { start_date: "2026-07-01", end_date: "2026-07-31" }))

    expect(parsed).to include(
      ["2026-07-08", "Transferência enviada", "Saída", "Transferência para Reserva", "", "Transferência", "Reserva", "-125.50"],
      ["2026-07-09", "Pagamento de fatura", "Saída", "Pagamento de fatura", "", "NUBANK", "", "-300.00"]
    )
  end

  it "exports archived accounts and an explicit message for a period without movements" do
    account.archive!

    parsed = rows(export(params: { start_date: "2026-08-01", end_date: "2026-08-31" }))

    expect(parsed).to include(
      ["Status", "Arquivada"],
      ["Saldo de abertura", "1000.00"],
      ["Saldo de fechamento", "1000.00"],
      ["Nenhuma movimentação no período."]
    )
  end

  it "sanitizes the account name in the filename" do
    result = Accounts::StatementBuilder.call(account: account, paginate: false)

    expect(described_class.filename(result, date: Date.new(2026, 7, 29))).to eq(
      "finch-extrato-conta-sao-joao-principal-2026-07-29.csv"
    )
  end
end
