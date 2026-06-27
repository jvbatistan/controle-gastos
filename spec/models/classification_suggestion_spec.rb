require 'rails_helper'

RSpec.describe ClassificationSuggestion, type: :model do
  it 'rejects a suggested category owned by another user' do
    user = create(:user)
    other_user = create(:user)
    transaction = create(:transaction, user: user, card: nil, source: :cash)
    other_category = create(:category, user: other_user)

    suggestion = build(
      :classification_suggestion,
      user: user,
      financial_transaction: transaction,
      suggested_category: other_category
    )

    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:suggested_category]).to include('deve pertencer ao mesmo usuário')
  end

  it 'rejects a financial transaction owned by another user' do
    user = create(:user)
    other_user = create(:user)
    other_transaction = create(:transaction, user: other_user, card: nil, source: :cash)
    category = create(:category, user: user)

    suggestion = build(
      :classification_suggestion,
      user: user,
      financial_transaction: other_transaction,
      suggested_category: category
    )

    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:financial_transaction]).to include('deve pertencer ao mesmo usuário')
  end
end
