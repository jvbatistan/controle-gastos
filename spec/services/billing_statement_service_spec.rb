require 'rails_helper'

RSpec.describe BillingStatementService do
  describe '#call' do
    it 'uses the next billing statement when the purchase happens on or after the closing day' do
      card = create(:card, due_day: 15, closing_day: 8)
      transaction = build(:transaction, card: card, user: card.user, date: Date.new(2026, 3, 8), source: :card)

      described_class.new(transaction).call

      expect(transaction.billing_statement).to eq(Date.new(2026, 4, 1))
    end

    it 'uses the current billing statement when the purchase happens before the closing day' do
      card = create(:card, due_day: 15, closing_day: 8)
      transaction = build(:transaction, card: card, user: card.user, date: Date.new(2026, 3, 7), source: :card)

      described_class.new(transaction).call

      expect(transaction.billing_statement).to eq(Date.new(2026, 3, 1))
    end

    it 'clamps closing days for shorter months' do
      card = create(:card, due_day: 31, closing_day: 31)
      transaction = build(:transaction, card: card, user: card.user, date: Date.new(2026, 2, 28), source: :card)

      described_class.new(transaction).call

      expect(transaction.billing_statement).to eq(Date.new(2026, 3, 1))
    end

    it 'falls back to the legacy closing offset when the card has not been migrated yet' do
      card = create(:card, due_date: 15, closing_date: 7, due_day: nil, closing_day: nil)
      transaction = build(:transaction, card: card, user: card.user, date: Date.new(2026, 3, 8), source: :card)

      described_class.new(transaction).call

      expect(transaction.billing_statement).to eq(Date.new(2026, 4, 1))
    end
  end
end
