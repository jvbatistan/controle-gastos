class ClassificationSuggestion < ApplicationRecord
  belongs_to :user
  
  belongs_to :financial_transaction, class_name: "Transaction", foreign_key: :financial_transaction_id
  belongs_to :suggested_category, class_name: 'Category', optional: true

  enum source: { alias: 0, rule: 1 }

  scope :pending, -> { where(accepted_at: nil, rejected_at: nil) }

  validate :transaction_must_belong_to_user
  validate :suggested_category_must_belong_to_user

  def pending?
    accepted_at.nil? && rejected_at.nil?
  end

  private

  def transaction_must_belong_to_user
    return if financial_transaction.nil? || user.nil?
    return if financial_transaction.user_id == user_id

    errors.add(:financial_transaction, 'deve pertencer ao mesmo usuário')
  end

  def suggested_category_must_belong_to_user
    return if suggested_category.nil? || user.nil?
    return if suggested_category.user_id == user_id

    errors.add(:suggested_category, 'deve pertencer ao mesmo usuário')
  end
end
