require 'rails_helper'

RSpec.describe Transactions::ApplyClassificationService do
  describe '.call' do
    it 'applies an accepted suggestion and learns the merchant alias' do
      user = create(:user)
      category = create(:category, user: user, name: 'Transporte')
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      described_class.call(
        suggestion: suggestion,
        category: category,
        learn: true,
        mark_as: :accepted,
        alias_confidence: suggestion.confidence
      )

      expect(transaction.reload.category).to eq(category)
      expect(suggestion.reload.accepted_at).to be_present
      expect(suggestion.rejected_at).to be_nil
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER').category).to eq(category)
    end

    it 'applies a corrected suggestion and learns the corrected merchant alias' do
      user = create(:user)
      suggested_category = create(:category, user: user, name: 'Transporte')
      corrected_category = create(:category, user: user, name: 'Alimentação')
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Eats Pedido 123')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: suggested_category,
        confidence: 0.6,
        source: :rule
      )

      described_class.call(
        suggestion: suggestion,
        category: corrected_category,
        learn: true,
        mark_as: :rejected,
        alias_confidence: 1.0
      )

      expect(transaction.reload.category).to eq(corrected_category)
      expect(suggestion.reload.accepted_at).to be_nil
      expect(suggestion.rejected_at).to be_present
      expect(user.merchant_aliases.find_by(normalized_merchant: 'UBER EATS').category).to eq(corrected_category)
    end

    it 'keeps the learn flag explicit and skips alias creation when learn is false' do
      user = create(:user)
      category = create(:category, user: user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      described_class.call(
        suggestion: suggestion,
        category: category,
        learn: false,
        mark_as: :accepted,
        alias_confidence: suggestion.confidence
      )

      expect(transaction.reload.category).to eq(category)
      expect(suggestion.reload.accepted_at).to be_present
      expect(user.merchant_aliases).to be_empty
    end

    it 'propagates the category and suggestion resolution to the user installment group' do
      user = create(:user)
      other_user = create(:user)
      category = create(:category, user: user)
      group_id = SecureRandom.uuid
      first_installment = create(
        :transaction,
        user: user,
        card: nil,
        category: nil,
        source: :cash,
        description: 'Compra parcelada',
        installment_group_id: group_id,
        installment_number: 1,
        installments_count: 3
      )
      second_installment = create(
        :transaction,
        user: user,
        card: nil,
        category: nil,
        source: :cash,
        description: 'Compra parcelada',
        installment_group_id: group_id,
        installment_number: 2,
        installments_count: 3
      )
      other_installment = create(
        :transaction,
        user: other_user,
        card: nil,
        category: nil,
        source: :cash,
        description: 'Compra parcelada',
        installment_group_id: group_id,
        installment_number: 3,
        installments_count: 3
      )
      first_installment.classification_suggestions.delete_all
      second_installment.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: first_installment,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )
      sibling_suggestion = user.classification_suggestions.create!(
        financial_transaction: second_installment,
        suggested_category: category,
        confidence: 0.97,
        source: :alias
      )

      described_class.call(
        suggestion: suggestion,
        category: category,
        learn: true,
        mark_as: :accepted,
        alias_confidence: suggestion.confidence
      )

      expect(first_installment.reload.category).to eq(category)
      expect(second_installment.reload.category).to eq(category)
      expect(other_installment.reload.category_id).to be_nil
      expect(suggestion.reload.accepted_at).to be_present
      expect(sibling_suggestion.reload.accepted_at).to be_present
    end

    it 'rejects a category owned by another user without applying or learning' do
      user = create(:user)
      other_user = create(:user)
      other_category = create(:category, user: other_user)
      transaction = create(:transaction, user: user, card: nil, category: nil, source: :cash, description: 'Uber Trip 1234')
      transaction.classification_suggestions.delete_all
      suggestion = user.classification_suggestions.create!(
        financial_transaction: transaction,
        confidence: 0.6,
        source: :rule
      )

      expect do
        described_class.call(
          suggestion: suggestion,
          category: other_category,
          learn: true,
          mark_as: :rejected,
          alias_confidence: 1.0
        )
      end.to raise_error(ActiveRecord::RecordNotFound)

      expect(transaction.reload.category_id).to be_nil
      expect(suggestion.reload.rejected_at).to be_nil
      expect(user.merchant_aliases).to be_empty
    end
  end
end
