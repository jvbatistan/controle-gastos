require 'rails_helper'

RSpec.describe 'ClassificationSuggestions', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'POST /classification_suggestions/:id/accept' do
    it 'applies the suggested category and learns a merchant alias' do
      category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER TRIP 1234',
        value: 32.9,
        date: Date.current,
        kind: :expense,
        source: :cash
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      post accept_classification_suggestion_path(suggestion)

      expect(response).to redirect_to(classification_suggestions_path)

      transaction.reload
      suggestion.reload
      alias_record = user.merchant_aliases.find_by(normalized_merchant: 'UBER')

      expect(transaction.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(alias_record).to be_present
      expect(alias_record.category_id).to eq(category.id)
      expect(alias_record.confidence).to be >= 0.97
    end

    it 'propagates the accepted category through the installment group' do
      category = create(:category, user: user, name: 'Eletronicos')
      group_id = 'grp-123'

      tx1 = user.transactions.create!(
        description: 'SMARTPHONE XYZ',
        value: 100,
        date: Date.current,
        kind: :expense,
        source: :card,
        installment_group_id: group_id,
        installment_number: 1,
        installments_count: 2
      )
      tx2 = user.transactions.create!(
        description: 'SMARTPHONE XYZ',
        value: 100,
        date: Date.current.next_month,
        kind: :expense,
        source: :card,
        installment_group_id: group_id,
        installment_number: 2,
        installments_count: 2
      )

      ClassificationSuggestion.where(financial_transaction_id: [tx1.id, tx2.id]).delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: tx1,
        suggested_category: category,
        confidence: 0.99,
        source: :alias
      )
      sibling_suggestion = user.classification_suggestions.create!(
        financial_transaction: tx2,
        suggested_category: category,
        confidence: 0.99,
        source: :alias
      )

      post accept_classification_suggestion_path(suggestion)

      expect(response).to redirect_to(classification_suggestions_path)

      tx1.reload
      tx2.reload
      suggestion.reload
      sibling_suggestion.reload

      expect(tx1.category_id).to eq(category.id)
      expect(tx2.category_id).to eq(category.id)
      expect(suggestion.accepted_at).to be_present
      expect(sibling_suggestion.accepted_at).to be_present
    end
  end

  describe 'POST /classification_suggestions/:id/reject' do
    it 'rejects the suggestion without changing the transaction category' do
      current_category = create(:category, user: user, name: 'Moradia')
      suggested_category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'CONDOMINIO',
        value: 250,
        date: Date.current,
        kind: :expense,
        source: :cash,
        category: current_category
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      post reject_classification_suggestion_path(suggestion)

      expect(response).to redirect_to(classification_suggestions_path)

      transaction.reload
      suggestion.reload

      expect(transaction.category_id).to eq(current_category.id)
      expect(suggestion.rejected_at).to be_present
    end
  end

  describe 'POST /classification_suggestions/:id/correct' do
    it 'applies the chosen category and learns the corrected alias' do
      corrected_category = create(:category, user: user, name: 'Alimentacao')
      suggested_category = create(:category, user: user, name: 'Transporte')
      transaction = user.transactions.create!(
        description: 'UBER EATS PEDIDO 123',
        value: 44.5,
        date: Date.current,
        kind: :expense,
        source: :cash
      )
      transaction.classification_suggestions.delete_all

      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      post correct_classification_suggestion_path(suggestion), params: {
        classification_suggestion: { category_id: corrected_category.id }
      }

      expect(response).to redirect_to(classification_suggestions_path)

      transaction.reload
      suggestion.reload
      alias_record = user.merchant_aliases.find_by(normalized_merchant: 'UBER EATS')

      expect(transaction.category_id).to eq(corrected_category.id)
      expect(suggestion.rejected_at).to be_present
      expect(alias_record).to be_present
      expect(alias_record.category_id).to eq(corrected_category.id)
      expect(alias_record.confidence).to eq(1.0)
    end
  end
end
