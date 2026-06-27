require 'rails_helper'

RSpec.describe Merchants::UpsertAliasService do
  it 'does not create an alias for a category owned by another user' do
    user = create(:user)
    other_user = create(:user)
    other_category = create(:category, user: other_user)

    expect do
      described_class.new(
        user: user,
        description: 'Uber Trip',
        category: other_category
      ).call
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(user.merchant_aliases).to be_empty
  end

  it 'creates an alias for a category owned by the user' do
    user = create(:user)
    category = create(:category, user: user)

    alias_record = described_class.new(
      user: user,
      description: 'Uber Trip',
      category: category
    ).call

    expect(alias_record.category).to eq(category)
    expect(alias_record.user).to eq(user)
  end
end
