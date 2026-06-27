require 'rails_helper'

RSpec.describe Transactions::ApplyCategoryToInstallmentGroupService do
  it 'updates only installments owned by the transaction user' do
    user = create(:user)
    other_user = create(:user)
    category = create(:category, user: user)
    group_id = SecureRandom.uuid
    own_installment = create(
      :transaction,
      user: user,
      card: nil,
      source: :cash,
      installment_group_id: group_id,
      installment_number: 1,
      installments_count: 2
    )
    other_installment = create(
      :transaction,
      user: other_user,
      card: nil,
      source: :cash,
      installment_group_id: group_id,
      installment_number: 2,
      installments_count: 2
    )

    described_class.new(transaction: own_installment, category: category).call

    expect(own_installment.reload.category).to eq(category)
    expect(other_installment.reload.category_id).to be_nil
  end

  it 'rejects a category owned by another user' do
    user = create(:user)
    other_user = create(:user)
    transaction = create(:transaction, user: user, card: nil, source: :cash)
    other_category = create(:category, user: other_user)

    expect do
      described_class.new(transaction: transaction, category: other_category).call
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
