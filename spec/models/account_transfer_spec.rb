require 'rails_helper'

RSpec.describe AccountTransfer, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:from_account).class_name('Account') }
    it { should belong_to(:to_account).class_name('Account') }
  end

  describe 'enums' do
    it 'keeps the status mapping stable' do
      expect(described_class.statuses).to eq(
        'completed' => 0,
        'reversed' => 1
      )
    end
  end

  describe 'validations' do
    subject { build(:account_transfer) }

    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:transferred_on) }

    it 'is valid with user, distinct active accounts, amount and date' do
      transfer = build(:account_transfer)

      expect(transfer).to be_valid
    end

    it 'requires user' do
      transfer = build(:account_transfer, user: nil)

      expect(transfer).not_to be_valid
      expect(transfer.errors[:user]).to be_present
    end

    it 'requires from account' do
      transfer = build(:account_transfer, from_account: nil)

      expect(transfer).not_to be_valid
      expect(transfer.errors[:from_account]).to be_present
    end

    it 'requires to account' do
      transfer = build(:account_transfer, to_account: nil)

      expect(transfer).not_to be_valid
      expect(transfer.errors[:to_account]).to be_present
    end

    it 'rejects the same account as origin and destination' do
      account = create(:account)
      transfer = build(:account_transfer, user: account.user, from_account: account, to_account: account)

      expect(transfer).not_to be_valid
      expect(transfer.errors[:to_account]).to include('deve ser diferente da conta de origem')
    end

    it 'rejects from account from another user' do
      user = create(:user)
      transfer = build(:account_transfer, user: user, from_account: create(:account), to_account: create(:account, user: user))

      expect(transfer).not_to be_valid
      expect(transfer.errors[:from_account]).to include('deve pertencer ao usuário')
    end

    it 'rejects to account from another user' do
      user = create(:user)
      transfer = build(:account_transfer, user: user, from_account: create(:account, user: user), to_account: create(:account))

      expect(transfer).not_to be_valid
      expect(transfer.errors[:to_account]).to include('deve pertencer ao usuário')
    end

    it 'rejects archived from account for a new transfer' do
      user = create(:user)
      from_account = create(:account, user: user, archived_at: Time.current)
      to_account = create(:account, user: user)
      transfer = build(:account_transfer, user: user, from_account: from_account, to_account: to_account)

      expect(transfer).not_to be_valid
      expect(transfer.errors[:from_account]).to include('não pode estar arquivada')
    end

    it 'rejects archived to account for a new transfer' do
      user = create(:user)
      from_account = create(:account, user: user)
      to_account = create(:account, user: user, archived_at: Time.current)
      transfer = build(:account_transfer, user: user, from_account: from_account, to_account: to_account)

      expect(transfer).not_to be_valid
      expect(transfer.errors[:to_account]).to include('não pode estar arquivada')
    end

    it 'allows transfer amount greater than current origin balance' do
      user = create(:user)
      from_account = create(:account, user: user, initial_balance: 10)
      to_account = create(:account, user: user)
      transfer = build(:account_transfer, user: user, from_account: from_account, to_account: to_account, amount: 100)

      expect(transfer).to be_valid
    end
  end
end
