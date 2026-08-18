require 'rails_helper'

RSpec.describe 'Api::ClassificationSuggestions', type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

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

  describe 'GET /api/classification_suggestions' do
    it 'paginates pending suggestions with safe defaults and a maximum' do
      category = create(:category, user: user)
      suggestions = 30.times.map do |index|
        transaction = create(:transaction, user: user, card: nil, source: :cash, account: account, description: "Suggestion #{index}")
        transaction.classification_suggestions.delete_all
        user.classification_suggestions.create!(financial_transaction: transaction, suggested_category: category, confidence: 0.8, source: :rule)
      end

      get '/api/classification_suggestions', params: { page: 2, per_page: 25 }
      body = JSON.parse(response.body)
      expect(body['pagination']).to eq('page' => 2, 'per_page' => 25, 'total_count' => 30, 'total_pages' => 2)
      expect(body['suggestions'].map { |item| item['id'] }).to eq(suggestions.first(5).reverse.map(&:id))

      get '/api/classification_suggestions', params: { page: 0, per_page: 999 }
      expect(JSON.parse(response.body)['pagination']).to include('page' => 1, 'per_page' => 100)

      metrics = request_metrics { get '/api/classification_suggestions', params: { page: 1, per_page: 25 } }
      warn("PERFORMANCE_1D_SUGGESTIONS #{metrics.inspect}") if ENV['PERFORMANCE_1D_METRICS'] == '1'
    end
    it 'lists pending suggestions with transaction data' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER TRIP 1234',
        value: 32.9,
        date: Date.current,
        kind: :expense,
        source: :cash,
        account: account
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      get '/api/classification_suggestions'

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body['pagination']).to include('page' => 1, 'per_page' => 25, 'total_count' => 1, 'total_pages' => 1)
      expect(body['suggestions'].size).to eq(1)
      expect(body['suggestions'].first['id']).to eq(suggestion.id)
      expect(body['suggestions'].first.dig('financial_transaction', 'id')).to eq(transaction.id)
      expect(body['suggestions'].first.dig('suggested_category', 'id')).to eq(category.id)
    end

    it 'keeps SELECTs effectively constant as the page grows' do
      category = create(:category, user: user)
      25.times do |index|
        transaction = create(:transaction, user: user, card: nil, source: :cash, account: account, description: "Suggestion #{index}")
        transaction.classification_suggestions.delete_all
        user.classification_suggestions.create!(financial_transaction: transaction, suggested_category: category, confidence: 0.8, source: :rule)
      end

      five_items = request_metrics { get '/api/classification_suggestions', params: { per_page: 5 } }
      twenty_five_items = request_metrics { get '/api/classification_suggestions', params: { per_page: 25 } }

      expect(JSON.parse(response.body)['suggestions'].size).to eq(25)
      expect(twenty_five_items[:selects]).to be <= 8
      expect(twenty_five_items[:selects]).to be <= five_items[:selects] + 1
      expect(twenty_five_items[:payload_bytes]).to be > five_items[:payload_bytes]
    end

    it 'keeps the status semantics for valid categories and pending suggestions' do
      category = create(:category, user: user)
      classified = create(:transaction, user: user, card: nil, source: :cash, account: account, category: category)
      classified.classification_suggestions.delete_all
      pending = create(:transaction, user: user, card: nil, source: :cash, account: account, category: nil)
      pending.classification_suggestions.delete_all
      classified_suggestion = user.classification_suggestions.create!(financial_transaction: classified, suggested_category: category, confidence: 0.8, source: :rule)
      pending_suggestion = user.classification_suggestions.create!(financial_transaction: pending, suggested_category: category, confidence: 0.8, source: :rule)

      get '/api/classification_suggestions'

      statuses = JSON.parse(response.body)['suggestions'].to_h do |item|
        [item['id'], item.dig('financial_transaction', 'classification_status')]
      end
      expect(statuses).to include(classified_suggestion.id => 'classified', pending_suggestion.id => 'suggestion_pending')
    end
  end

  describe 'POST /api/classification_suggestions/:id/accept' do
    it 'accepts the suggestion and learns the alias' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER TRIP 1234',
        value: 32.9,
        date: Date.current,
        kind: :expense,
        source: :cash,
        account: account
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      post "/api/classification_suggestions/#{suggestion.id}/accept"

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload
      body = JSON.parse(response.body)

      expect(transaction.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER').category_id).to eq(category.id)
      expect(body.dig('financial_transaction', 'classification_status')).to eq('classified')
    end

    it 'does not accept a historically inconsistent suggestion pointing to another user category' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      own_category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash)
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: own_category,
        confidence: 0.97,
        source: :alias
      )
      suggestion.update_column(:suggested_category_id, other_category.id)

      post "/api/classification_suggestions/#{suggestion.id}/accept"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end
  end

  describe 'POST /api/classification_suggestions/:id/apply' do
    it 'applies the category without learning an alias when learn is false' do
      category = create(:category, user: user, name: 'Excecao')
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id,
        learn: false
      }, as: :json

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload
      body = JSON.parse(response.body)

      expect(transaction.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
      expect(body.dig('financial_transaction', 'category', 'id')).to eq(category.id)
      expect(body.dig('financial_transaction', 'classification_status')).to eq('classified')
    end

    it 'applies the category and learns an alias when learn is true' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload

      expect(transaction.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER').category_id).to eq(category.id)
    end

    it 'updates an existing alias when learn is true' do
      old_category = create(:category, user: user, name: 'Antiga')
      new_category = create(:category, user: user, name: 'Nova')
      MerchantAlias.create!(
        user: user,
        normalized_merchant: 'UBER',
        category: old_category,
        confidence: 0.95,
        source: :user_override
      )
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: new_category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER').category_id).to eq(new_category.id)
      expect(user.merchant_aliases.where(normalized_merchant: 'UBER').count).to eq(1)
    end

    it 'requires category_id without changing records' do
      category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        learn: true
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq('error' => 'category_id is required')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'requires learn without changing records' do
      category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq('error' => 'learn is required')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'rejects invalid learn values without changing records' do
      category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: category.id,
        learn: 'maybe'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq('error' => 'learn must be a boolean')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'does not apply or learn a category from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/apply", params: {
        category_id: other_category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end

    it 'does not reveal or apply a suggestion from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      other_transaction = create(:transaction, user: other_user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      other_transaction.classification_suggestions.delete_all
      other_suggestion = other_user.classification_suggestions.create!(
        financial_transaction: other_transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{other_suggestion.id}/apply", params: {
        category_id: other_category.id,
        learn: true
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(other_transaction.reload.category_id).to be_nil
      expect(other_suggestion.reload.accepted_at).to be_nil
      expect(other_suggestion.rejected_at).to be_nil
      expect(other_user.merchant_aliases).to be_empty
    end
  end

  describe 'POST /api/classification_suggestions/:id/reject' do
    it 'rejects the suggestion' do
      transaction = user.transactions.create!(
        description: 'LOJA XPTO',
        value: 50,
        date: Date.current,
        kind: :expense,
        source: :cash,
        account: account
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.5,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/reject"

      expect(response).to have_http_status(:ok)

      suggestion.reload
      body = JSON.parse(response.body)

      expect(suggestion.rejected_at).to be_present
      expect(body['rejected_at']).to be_present
    end
  end

  describe 'POST /api/classification_suggestions/:id/correct' do
    it 'corrects the suggestion and learns the alias' do
      corrected_category = create(:category, user: user, name: 'Alimentacao')
      suggested_category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER EATS PEDIDO 123',
        value: 44.5,
        date: Date.current,
        kind: :expense,
        source: :cash,
        account: account
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/correct", params: {
        classification_suggestion: { category_id: corrected_category.id }
      }

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload
      body = JSON.parse(response.body)

      expect(transaction.category_id).to eq(corrected_category.id)
      expect(suggestion.rejected_at).to be_present
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER EATS').category_id).to eq(corrected_category.id)
      expect(body.dig('financial_transaction', 'category', 'id')).to eq(corrected_category.id)
    end

    it 'corrects the suggestion without learning an alias when merchant normalizes to blank' do
      corrected_category = create(:category, user: user, name: 'Alimentacao')
      suggested_category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: '1234 - 5678',
        value: 44.5,
        date: Date.current,
        kind: :expense,
        source: :cash,
        account: account
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/correct", params: {
        classification_suggestion: { category_id: corrected_category.id }
      }

      expect(response).to have_http_status(:ok)

      transaction.reload
      suggestion.reload

      expect(transaction.category_id).to eq(corrected_category.id)
      expect(suggestion.rejected_at).to be_present
      expect(user.merchant_aliases).to be_empty
    end

    it 'does not apply or learn an alias for a category from another user' do
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      suggested_category = create(:category, user: user)
      transaction = create(
        :transaction,
        user: user,
        card: nil,
        category: nil,
        source: :cash,
        description: 'Uber Eats Pedido'
      )
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      post "/api/classification_suggestions/#{suggestion.id}/correct", params: {
        classification_suggestion: { category_id: other_category.id }
      }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Not found')
      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end
  end
end
