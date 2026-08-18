require 'rails_helper'

RSpec.describe 'Api::Transactions', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  def select_query_count
    count = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      sql = payload[:sql].to_s
      count += 1 if sql.match?(/\ASELECT/i) && !payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
    count
  end

  describe 'POST /api/transactions' do
    it 'auto-classifies when an exact alias exists' do
      category = create(:category, user: user, name: 'Transporte')
      account = create(:account, user: user)
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'UBER',
        category: category,
        confidence: 1.0,
        source: :user_override
      )

      post '/api/transactions', params: {
        transaction: {
          description: 'Uber Trip 1234',
          value: '32,90',
          date: Date.current,
          kind: 'expense',
          source: 'cash',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transaction = Transaction.find(body['id'])

      expect(transaction.category_id).to eq(category.id)
      expect(transaction.classification_suggestions.pending.count).to eq(0)
      expect(body.dig('category', 'id')).to eq(category.id)
    end

    it 'creates a pending suggestion when no confident match exists' do
      account = create(:account, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Loja XPTO Centro',
          value: '89,10',
          date: Date.current,
          kind: 'expense',
          source: 'cash',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transaction = Transaction.find(body['id'])

      expect(transaction.category_id).to be_nil
      expect(transaction.classification_suggestions.pending.count).to eq(1)
      expect(body['category']).to be_nil
    end

    it 'rejects a card from another user' do
      other_user = create(:user)
      other_card = create(:card, user: other_user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Compra teste',
          value: '15,00',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: other_card.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to be_present
    end

    it 'does not reveal or accept a category from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      account = create(:account, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Compra teste',
          value: '15,00',
          date: Date.current,
          kind: 'expense',
          source: 'cash',
          account_id: account.id,
          category_id: other_category.id
        }
      }

      cross_user_response = [response.status, JSON.parse(response.body)]

      post '/api/transactions', params: {
        transaction: {
          description: 'Compra teste',
          value: '15,00',
          date: Date.current,
          kind: 'expense',
          source: 'cash',
          account_id: account.id,
          category_id: Category.maximum(:id).to_i + 10_000
        }
      }

      missing_response = [response.status, JSON.parse(response.body)]

      expect(cross_user_response).to eq([404, { 'error' => 'Not found' }])
      expect(missing_response).to eq(cross_user_response)
      expect(user.transactions.where(description: 'COMPRA TESTE')).to be_empty
    end

    it 'creates a transaction with a category owned by the current user' do
      category = create(:category, user: user)
      account = create(:account, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Compra categorizada',
          value: '15,00',
          date: Date.current,
          kind: 'expense',
          source: 'cash',
          account_id: account.id,
          category_id: category.id
        }
      }

      expect(response).to have_http_status(:created)
      expect(user.transactions.find(JSON.parse(response.body)['id']).category).to eq(category)
    end

    it 'creates a simple income without requiring card, statement or installment fields' do
      account = create(:account, user: user, name: 'Conta Corrente')

      post '/api/transactions', params: {
        transaction: {
          description: 'Salario mensal',
          value: '3500,00',
          date: Date.new(2026, 6, 30),
          kind: 'income',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transaction = user.transactions.find(body['id'])

      expect(transaction.kind).to eq('income')
      expect(transaction.source).to eq('bank')
      expect(transaction.account).to eq(account)
      expect(transaction.value.to_d).to eq(BigDecimal('3500'))
      expect(transaction.paid).to eq(true)
      expect(transaction.card_id).to be_nil
      expect(transaction.billing_statement).to be_nil
      expect(transaction.installment_group_id).to be_nil
      expect(transaction.installment_number).to be_nil
      expect(transaction.installments_count).to be_nil
      expect(transaction.payment_ignored_at).to be_nil
      expect(transaction.refund).to eq(false)
      expect(body['kind']).to eq('income')
      expect(body['source']).to eq('bank')
      expect(body['paid']).to eq(true)
      expect(body['card']).to be_nil
      expect(body.dig('account', 'id')).to eq(account.id)
      expect(body.dig('account', 'name')).to eq('Conta Corrente')
      expect(body['billing_statement']).to be_nil
    end

    it 'rejects income without account' do
      post '/api/transactions', params: {
        transaction: {
          description: 'Receita sem conta',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'bank'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account é obrigatória para receitas')
    end

    it 'rejects income with an account from another user' do
      other_account = create(:account, user: create(:user))

      post '/api/transactions', params: {
        transaction: {
          description: 'Receita cross user',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'bank',
          account_id: other_account.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account inválida')
      expect(user.transactions.where(description: 'RECEITA CROSS USER')).to be_empty
    end

    it 'rejects income with an archived account' do
      account = create(:account, user: user, archived_at: Time.current)

      post '/api/transactions', params: {
        transaction: {
          description: 'Receita conta arquivada',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'bank',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account não pode estar arquivada')
    end

    it 'rejects income with a missing account' do
      post '/api/transactions', params: {
        transaction: {
          description: 'Receita conta inexistente',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'bank',
          account_id: Account.maximum(:id).to_i + 10_000
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account inválida')
    end

    it 'rejects income with source card' do
      account = create(:account, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Receita no cartao',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'card',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Source não pode ser cartão para receitas')
    end

    it 'rejects income with a card' do
      card = create(:card, user: user)
      account = create(:account, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Receita com cartao',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'bank',
          account_id: account.id,
          card_id: card.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Card não deve existir para receitas')
    end

    it 'rejects income with a billing statement' do
      account = create(:account, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Receita com fatura',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'bank',
          account_id: account.id,
          billing_statement: '2026-07-01'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Billing statement não deve existir para receitas')
    end

    it 'rejects income with installment params before generating installments' do
      account = create(:account, user: user)

      expect do
        post '/api/transactions', params: {
          transaction: {
            description: 'Receita parcelada',
            value: '100,00',
            date: Date.current,
            kind: 'income',
            source: 'bank',
            account_id: account.id,
            installment_number: 1,
            installments_count: 2
          }
        }
      end.not_to change(Transaction, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('Receita não pode ser parcelada')
    end

    it 'rejects income with refund flag' do
      account = create(:account, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Receita estorno',
          value: '100,00',
          date: Date.current,
          kind: 'income',
          source: 'bank',
          account_id: account.id,
          refund: true
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Refund não pode ser verdadeiro para receitas')
    end

    it 'accepts a card refund and returns its signed value' do
      card = create(:card, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Uber - Nupay',
          value: '6,92',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: card.id,
          refund: true
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transaction = Transaction.find(body['id'])

      expect(transaction.value.to_d).to eq(BigDecimal('6.92'))
      expect(transaction.refund).to eq(true)
      expect(transaction.kind).to eq('expense')
      expect(transaction.source).to eq('card')
      expect(body['refund']).to eq(true)
      expect(body['signed_value']).to eq('-6.92')
    end

    it 'creates a cash expense with an active account from the current user' do
      account = create(:account, user: user, name: 'Carteira')

      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa dinheiro',
          value: '10,00',
          date: Date.current,
          kind: 'expense',
          source: 'cash',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transaction = user.transactions.find(body['id'])
      expect(transaction.account).to eq(account)
      expect(body.dig('account', 'id')).to eq(account.id)
      expect(body.dig('account', 'name')).to eq('Carteira')
    end

    it 'creates a bank expense with an active account from the current user' do
      account = create(:account, user: user, name: 'Conta Corrente')

      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa banco',
          value: '10,00',
          date: Date.current,
          kind: 'expense',
          source: 'bank',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      expect(user.transactions.find(body['id']).account).to eq(account)
      expect(body.dig('account', 'name')).to eq('Conta Corrente')
    end

    it 'creates a new unpaid cash or bank expense without account' do
      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa sem conta',
          value: '10,00',
          date: Date.current,
          kind: 'expense',
          source: 'cash'
        }
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['account']).to be_nil
    end

    it 'rejects a paid cash or bank expense without account' do
      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa paga sem conta', value: '10,00', date: Date.current,
          kind: 'expense', source: 'bank', paid: true
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account é obrigatória para despesas sem cartão')
    end

    it 'rejects a cash or bank expense with an account from another user' do
      other_account = create(:account, user: create(:user))

      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa cross user',
          value: '10,00',
          date: Date.current,
          kind: 'expense',
          source: 'bank',
          account_id: other_account.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account inválida')
      expect(user.transactions.where(description: 'DESPESA CROSS USER')).to be_empty
    end

    it 'rejects a cash or bank expense with an archived account' do
      account = create(:account, user: user, archived_at: Time.current)

      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa conta arquivada',
          value: '10,00',
          date: Date.current,
          kind: 'expense',
          source: 'cash',
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account não pode estar arquivada')
    end

    it 'rejects a cash or bank expense with a missing account' do
      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa conta inexistente',
          value: '10,00',
          date: Date.current,
          kind: 'expense',
          source: 'bank',
          account_id: Account.maximum(:id).to_i + 10_000
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account inválida')
    end

    it 'rejects account_id on card expenses' do
      account = create(:account, user: user)
      card = create(:card, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Despesa cartao com conta',
          value: '10,00',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: card.id,
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('Account não deve existir para despesas no cartão')
    end

    it 'rejects installment refunds' do
      card = create(:card, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Uber - Nupay',
          value: '6,92',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: card.id,
          refund: true,
          installment_number: 1,
          installments_count: 2
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('Estorno não pode ser parcelado')
    end

    it 'rejects clear card statement payments as transactions' do
      card = create(:card, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'Pagamento recebido para liberar limite',
          value: '1969,20',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: card.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('pagamento de fatura deve ser registrado na tela de pagamentos')
    end

    it 'reprocesses classification when the description changes' do
      category = create(:category, user: user, name: 'Transporte')
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'UBER',
        category: category,
        confidence: 1.0,
        source: :user_override
      )

      transaction = user.transactions.create!(
        description: 'Loja XPTO Centro',
        value: 50,
        date: Date.current,
        kind: :expense,
        source: :cash,
        account: create(:account, user: user)
      )

      expect(transaction.classification_suggestions.pending.count).to eq(1)

      patch "/api/transactions/#{transaction.id}", params: {
        transaction: {
          description: 'Uber Trip 1234'
        }
      }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      transaction.reload

      expect(transaction.category_id).to eq(category.id)
      expect(transaction.classification_suggestions.pending.count).to eq(0)
      expect(body.dig('classification', 'status')).to eq('classified')
      expect(body.dig('classification', 'category', 'id')).to eq(category.id)
      expect(body.dig('classification', 'suggestion')).to be_nil
    end

    it 'creates one pending suggestion for the whole installment group' do
      card = create(:card, user: user)

      post '/api/transactions', params: {
        transaction: {
          description: 'SMARTPHONE XPTO 10X',
          value: '199,90',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: card.id,
          installment_number: 1,
          installments_count: 3
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      group_id = body['installment_group_id']
      transactions = user.transactions.where(installment_group_id: group_id).order(:installment_number)
      suggestion_ids = transactions.map { |tx| tx.pending_classification_suggestion&.id }.uniq

      expect(group_id).to be_present
      expect(transactions.count).to eq(3)
      expect(ClassificationSuggestion.pending.where(financial_transaction_id: transactions.pluck(:id)).count).to eq(1)
      expect(suggestion_ids.size).to eq(1)
      expect(suggestion_ids.first).to be_present
      expect(body['transactions'].size).to eq(3)
      expect(body['transactions'].map { |tx| tx.dig('classification', 'status') }.uniq).to eq(['suggestion_pending'])
      expect(body['transactions'].map { |tx| tx.dig('classification', 'suggestion', 'id') }.uniq.size).to eq(1)
    end

    it 'propagates auto-classification to every installment in the group' do
      card = create(:card, user: user)
      category = create(:category, user: user, name: 'Transporte')
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'UBER',
        category: category,
        confidence: 1.0,
        source: :user_override
      )

      post '/api/transactions', params: {
        transaction: {
          description: 'Uber Trip 1234',
          value: '55,00',
          date: Date.current,
          kind: 'expense',
          source: 'card',
          card_id: card.id,
          installment_number: 1,
          installments_count: 2
        }
      }

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      transactions = user.transactions.where(installment_group_id: body['installment_group_id']).order(:installment_number)

      expect(transactions.count).to eq(2)
      expect(transactions.pluck(:category_id).uniq).to eq([category.id])
      expect(ClassificationSuggestion.pending.where(financial_transaction_id: transactions.pluck(:id)).count).to eq(0)
      expect(body['transactions'].map { |tx| tx.dig('classification', 'status') }.uniq).to eq(['classified'])
      expect(body['transactions'].map { |tx| tx.dig('classification', 'category', 'id') }.uniq).to eq([category.id])
    end
  end

  describe 'GET /api/transactions' do
    it 'does not return archived transactions' do
      visible = create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 10), value: 80)
      hidden = create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 11), value: 50, archived_at: Time.current)

      get '/api/transactions', params: { month: 3, year: 2026 }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.map { |transaction| transaction['id'] }).to eq([visible.id])
      expect(body.map { |transaction| transaction['id'] }).not_to include(hidden.id)
    end

    it 'keeps association queries bounded as the response grows' do
      category = create(:category, user: user)
      card = create(:card, user: user)
      account = create(:account, user: user)

      6.times do |index|
        create(:transaction, user: user, card: card, category: category, description: "Card #{index}")
        create(:transaction, user: user, card: nil, account: account, category: category, source: :cash, paid: true, description: "Cash #{index}")
      end

      queries = select_query_count { get '/api/transactions', params: { limit: 50 } }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(12)
      expect(queries).to be <= 12
    end

    it 'keeps the newest pending suggestion from an installment group outside the response page' do
      card = create(:card, user: user)
      group_id = SecureRandom.uuid
      older_installment = create(
        :transaction,
        user: user,
        card: card,
        installment_group_id: group_id,
        installment_number: 1,
        installments_count: 2,
        date: Date.current - 1.month
      )
      visible_installment = create(
        :transaction,
        user: user,
        card: card,
        installment_group_id: group_id,
        installment_number: 2,
        installments_count: 2,
        date: Date.current
      )
      older_installment.classification_suggestions.delete_all
      visible_installment.classification_suggestions.delete_all
      suggestion = create(:classification_suggestion, user: user, financial_transaction: older_installment)

      get '/api/transactions', params: { limit: 1 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body).first
      expect(body['id']).to eq(visible_installment.id)
      expect(body.dig('classification', 'status')).to eq('suggestion_pending')
      expect(body.dig('classification', 'suggestion', 'id')).to eq(suggestion.id)
    end
  end

  describe 'PATCH /api/transactions/:id' do
    it 'updates the selected transaction through the API' do
      card = create(:card, user: user, name: 'Nubank', due_day: 15, closing_day: 8)
      transaction = create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 10), value: 80, description: 'Uber')

      patch "/api/transactions/#{transaction.id}", params: {
        transaction: {
          description: 'Mercado do bairro',
          value: '125,90',
          date: '2026-03-15',
          source: 'card',
          card_id: card.id,
          account_id: nil,
          paid: true,
          note: 'Compra mensal'
        }
      }

      expect(response).to have_http_status(:ok)

      transaction.reload
      body = JSON.parse(response.body)
      expect(transaction.description).to eq('MERCADO DO BAIRRO')
      expect(transaction.value.to_d).to eq(BigDecimal('125.9'))
      expect(transaction.source).to eq('card')
      expect(transaction.card_id).to eq(card.id)
      expect(transaction.billing_statement).to eq(Date.new(2026, 4, 1))
      expect(transaction.paid).to eq(true)
      expect(transaction.note).to eq('Compra mensal')
      expect(body['id']).to eq(transaction.id)
      expect(body['card']['id']).to eq(card.id)
      expect(body['account']).to be_nil
    end

    it 'keeps a legacy cash expense without account editable when account-relevant fields do not change' do
      transaction = build(:transaction, user: user, card: nil, account: nil, source: :cash, description: 'Despesa legada')
      transaction.save!(validate: false)

      patch "/api/transactions/#{transaction.id}", params: {
        transaction: {
          description: 'Despesa legada ajustada',
          note: 'Apenas observação'
        }
      }

      expect(response).to have_http_status(:ok)

      transaction.reload
      body = JSON.parse(response.body)
      expect(transaction.account_id).to be_nil
      expect(transaction.description).to eq('DESPESA LEGADA AJUSTADA')
      expect(transaction.note).to eq('Apenas observação')
      expect(body['account']).to be_nil
    end

    it 'allows converting an unpaid card expense to cash or bank without account' do
      card = create(:card, user: user)
      transaction = create(:transaction, user: user, card: card, source: :card)

      patch "/api/transactions/#{transaction.id}", params: {
        transaction: {
          source: 'cash',
          card_id: nil
        }
      }

      expect(response).to have_http_status(:ok)
      expect(transaction.reload).to be_cash
      expect(transaction.account_id).to be_nil
    end

    it 'does not update a transaction with a category from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash)

      patch "/api/transactions/#{transaction.id}", params: {
        transaction: { category_id: other_category.id }
      }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(transaction.reload.category_id).to be_nil
    end
  end

  describe 'DELETE /api/transactions/:id' do
    it 'archives the transaction instead of deleting it' do
      transaction = create(:transaction, user: user, card: nil, source: :cash, date: Date.new(2026, 3, 10), value: 80)

      delete "/api/transactions/#{transaction.id}"

      expect(response).to have_http_status(:no_content)

      transaction.reload
      expect(transaction.archived_at).to be_present
    end
  end
end
