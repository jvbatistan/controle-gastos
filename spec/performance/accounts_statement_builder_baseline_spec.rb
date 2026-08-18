require 'rails_helper'

RSpec.describe 'Accounts statement performance baseline', type: :request do
  [100, 1_000, 5_000].each do |volume|
    next unless ENV['PERFORMANCE_1E_METRICS'] == '1'

    it "measures #{volume} mixed movements" do
      user = create(:user)
      account = create(:account, user: user, initial_balance: 100, initial_balance_date: Date.new(2020, 1, 1))
      counterparty = create(:account, user: user)
      card = create(:card, user: user)
      statement = create(:card_statement, card: card)
      sign_in user
      now = Time.zone.parse('2026-08-18 12:00:00')
      transaction_count = (volume * 0.6).to_i
      payment_count = (volume * 0.2).to_i
      transfer_count = volume - transaction_count - payment_count

      Transaction.insert_all(Array.new(transaction_count) do |index|
        income = index.even?
        {
          user_id: user.id, account_id: account.id, description: "MOVEMENT #{index}", value: 10,
          date: Date.new(2020, 1, 1) + index.days, kind: income ? Transaction.kinds[:income] : Transaction.kinds[:expense],
          source: Transaction.sources[:bank], paid: true, refund: false, created_at: now + index.seconds, updated_at: now
        }
      end)
      CardStatementPayment.insert_all(Array.new(payment_count) do |index|
        { card_statement_id: statement.id, account_id: account.id, amount: 5, paid_at: now + index.minutes,
          description: "PAYMENT #{index}", created_at: now + index.seconds, updated_at: now }
      end)
      AccountTransfer.insert_all(Array.new(transfer_count) do |index|
        outgoing = index.even?
        { user_id: user.id, from_account_id: outgoing ? account.id : counterparty.id,
          to_account_id: outgoing ? counterparty.id : account.id, amount: 3,
          transferred_on: Date.new(2020, 1, 1) + index.days, status: AccountTransfer.statuses[:completed],
          description: "TRANSFER #{index}", created_at: now + index.seconds, updated_at: now }
      end)

      selects = 0
      entries = 0
      sql_callback = ->(_name, _start, _finish, _id, payload) { selects += 1 if !payload[:cached] && payload[:sql].to_s.match?(/\A\s*SELECT/i) }
      allow(Accounts::StatementEntry).to receive(:new).and_wrap_original { |original, **args| entries += 1; original.call(**args) }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ActiveSupport::Notifications.subscribed(sql_callback, 'sql.active_record') do
        get "/api/accounts/#{account.id}/statement", params: { page: 1, per_page: 25 }
      end
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000).round(1)
      body = JSON.parse(response.body)

      warn "PERFORMANCE_1E volume=#{volume} total_count=#{body.dig('pagination', 'total_count')} returned=#{body.fetch('items').size} selects=#{selects} entries=#{entries} payload_bytes=#{response.body.bytesize} duration_ms=#{duration_ms}"
      expect(response).to have_http_status(:ok)
      expect(body.fetch('items').size).to eq(25)
      expect(body.dig('pagination', 'total_count')).to eq(volume + 1)
    end
  end
end
