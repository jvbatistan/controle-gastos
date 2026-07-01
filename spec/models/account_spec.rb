require 'rails_helper'

RSpec.describe Account, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:account) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:kind) }
    it { should validate_presence_of(:initial_balance) }
    it { should validate_numericality_of(:initial_balance).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:initial_balance_date) }

    it 'rejects duplicate names for the same user ignoring case' do
      user = create(:user)
      create(:account, user: user, name: 'Nubank')

      account = build(:account, user: user, name: 'nubank')

      expect(account).not_to be_valid
      expect(account.errors[:name]).to be_present
    end

    it 'allows the same name for different users' do
      create(:account, user: create(:user), name: 'Nubank')

      account = build(:account, user: create(:user), name: 'Nubank')

      expect(account).to be_valid
    end

    it 'rejects invalid kind values' do
      account = build(:account)

      expect {
        account.kind = 'investment'
      }.to raise_error(ArgumentError)
    end
  end

  describe 'enums' do
    it 'keeps the MVP kind mapping stable' do
      expect(described_class.kinds).to eq(
        'checking' => 0,
        'savings' => 1,
        'wallet' => 2,
        'digital_wallet' => 3,
        'other' => 4
      )
    end
  end

  describe '#current_balance' do
    it 'returns the initial balance while transactions are not linked to accounts' do
      account = build(:account, initial_balance: 123.45)

      expect(account.current_balance).to eq(123.45.to_d)
    end
  end

  describe 'archiving' do
    it 'archives and restores without deleting the record' do
      account = create(:account)

      account.archive!

      expect(account.reload).to be_archived
      expect(Account.exists?(account.id)).to eq(true)

      account.restore!

      expect(account.reload).not_to be_archived
    end
  end
end
