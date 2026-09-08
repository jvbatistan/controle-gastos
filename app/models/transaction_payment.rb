class TransactionPayment < ApplicationRecord
  belongs_to :financial_transaction, class_name: 'Transaction', foreign_key: :transaction_id, inverse_of: :transaction_payments
  belongs_to :account

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :settled_on, presence: true
  validate :account_belongs_to_transaction_user
  validate :account_is_active
  validate :transaction_is_loose_expense

  private

  def account_belongs_to_transaction_user
    return if account.blank? || financial_transaction.blank? || account.user_id == financial_transaction.user_id

    errors.add(:account, 'deve pertencer ao mesmo usuário da despesa')
  end

  def account_is_active
    errors.add(:account, 'não pode estar arquivada') if account&.archived?
  end

  def transaction_is_loose_expense
    return if financial_transaction.blank? || financial_transaction.loose_expense?

    errors.add(:transaction, 'deve ser uma despesa avulsa')
  end
end
