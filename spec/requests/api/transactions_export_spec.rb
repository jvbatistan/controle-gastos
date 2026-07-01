require 'rails_helper'
require 'csv'

RSpec.describe 'Api::Transactions CSV export', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  def parsed_csv
    CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';', headers: true)
  end

  describe 'GET /api/transactions/export_csv' do
    it 'returns CSV headers suitable for download' do
      get '/api/transactions/export_csv'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('finch-transacoes-')
      expect(response.headers['Content-Disposition']).to include('.csv')
      expect(response.body).to start_with("\uFEFF")
    end

    it 'exports only active transactions owned by the authenticated user' do
      own_transaction = create(:transaction, user: user, card: nil, source: :cash, description: 'Mercado local')
      create(:transaction, user: user, card: nil, source: :cash, description: 'Arquivada', archived_at: Time.current)
      other_user = create(:user)
      create(:transaction, user: other_user, card: nil, source: :cash, description: 'Outro usuario')

      get '/api/transactions/export_csv'

      rows = parsed_csv
      expect(rows.map { |row| row['ID'].to_i }).to eq([own_transaction.id])
      expect(rows.map { |row| row['Descrição'] }).to eq(['MERCADO LOCAL'])
    end

    it 'respects month and year filters using date for loose transactions and billing statement for card transactions' do
      card = create(:card, user: user, closing_day: 8)
      loose_in_period = create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 20), description: 'Dinheiro marco')
      card_in_period = create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 5), description: 'Cartao marco')
      create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 4, 1), description: 'Dinheiro abril')
      create(:transaction, user: user, card: card, source: :card, date: Date.new(2026, 3, 10), description: 'Cartao abril')

      get '/api/transactions/export_csv', params: { month: 3, year: 2026 }

      ids = parsed_csv.map { |row| row['ID'].to_i }
      expect(ids).to contain_exactly(loose_in_period.id, card_in_period.id)
    end

    it 'respects the card filter' do
      first_card = create(:card, user: user, name: 'NUBANK')
      second_card = create(:card, user: user, name: 'INTER')
      included = create(:transaction, user: user, card: first_card, source: :card, description: 'Compra Nubank')
      create(:transaction, user: user, card: second_card, source: :card, description: 'Compra Inter')
      create(:transaction, user: user, card: nil, source: :cash, description: 'Compra dinheiro')

      get '/api/transactions/export_csv', params: { card_id: first_card.id }

      rows = parsed_csv
      expect(rows.map { |row| row['ID'].to_i }).to eq([included.id])
      expect(rows.first['Cartão']).to eq('NUBANK')
    end

    it 'respects the without-card filter' do
      card = create(:card, user: user)
      included = create(:transaction, user: user, card: nil, source: :bank, description: 'Pix mercado')
      create(:transaction, user: user, card: card, source: :card, description: 'Compra cartao')

      get '/api/transactions/export_csv', params: { card_id: 'none' }

      rows = parsed_csv
      expect(rows.map { |row| row['ID'].to_i }).to eq([included.id])
      expect(rows.first['Origem']).to eq('banco')
      expect(rows.first['Cartão']).to eq('')
    end

    it 'respects the visible limit used by the listing' do
      newest = create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 3), description: 'Mais recente')
      create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 2), description: 'Mais antiga')

      get '/api/transactions/export_csv', params: { limit: 1 }

      expect(parsed_csv.map { |row| row['ID'].to_i }).to eq([newest.id])
    end

    it 'exports the main transaction fields with normalized labels' do
      card = create(:card, user: user, name: 'NUBANK', closing_day: 8)
      category = create(:category, user: user, name: 'Mercado')
      transaction = create(
        :transaction,
        user: user,
        card: card,
        category: category,
        source: :card,
        date: Date.new(2026, 3, 10),
        value: BigDecimal('123.45'),
        refund: false,
        paid: true,
        description: 'Mercado parcelado',
        note: 'Ajuste da compra',
        responsible: 'Maria',
        installment_group_id: 'grupo-123',
        installment_number: 2,
        installments_count: 5,
        payment_ignored_at: Time.zone.parse('2026-03-12 10:00:00')
      )

      get '/api/transactions/export_csv', params: { card_id: card.id }

      row = parsed_csv.first
      expect(row.to_h).to include(
        'ID' => transaction.id.to_s,
        'Data' => '2026-03-10',
        'Competência/Fatura' => '2026-04-01',
        'Descrição' => 'MERCADO PARCELADO',
        'Observação' => 'Ajuste da compra',
        'Tipo' => 'despesa',
        'Origem' => 'cartão',
        'Conta' => '',
        'Cartão' => 'NUBANK',
        'Categoria' => 'Mercado',
        'Responsável' => 'MARIA',
        'Valor' => '123.45',
        'Valor assinado' => '123.45',
        'Pago?' => 'sim',
        'Parcela atual' => '2',
        'Total de parcelas' => '5',
        'Grupo de parcelamento' => 'grupo-123',
        'Arquivado?' => 'não',
        'Ignorado no pagamento?' => 'sim'
      )
      expect(row['Criado em']).to match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/)
      expect(row['Atualizado em']).to match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/)
    end

    it 'exports income rows without card, statement, installment or payment ignore fields' do
      account = create(:account, user: user, name: 'Conta Corrente')
      income = create(
        :transaction,
        user: user,
        account: account,
        card: nil,
        kind: :income,
        source: :bank,
        date: Date.new(2026, 6, 30),
        value: BigDecimal('3500'),
        paid: false,
        description: 'Salario mensal'
      )

      get '/api/transactions/export_csv', params: { card_id: 'none', month: 6, year: 2026 }

      row = parsed_csv.first
      expect(row.to_h).to include(
        'ID' => income.id.to_s,
        'Data' => '2026-06-30',
        'Competência/Fatura' => '',
        'Descrição' => 'SALARIO MENSAL',
        'Tipo' => 'receita',
        'Origem' => 'banco',
        'Conta' => 'Conta Corrente',
        'Cartão' => '',
        'Valor' => '3500.00',
        'Valor assinado' => '3500.00',
        'Pago?' => 'sim',
        'Parcela atual' => '',
        'Total de parcelas' => '',
        'Grupo de parcelamento' => '',
        'Ignorado no pagamento?' => 'não'
      )
    end
  end
end
