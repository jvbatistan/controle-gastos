class ClassificationSuggestion < ApplicationRecord
  belongs_to :user
  
  belongs_to :financial_transaction, class_name: "Transaction", foreign_key: :financial_transaction_id
  belongs_to :suggested_category, class_name: 'Category', optional: true

  enum source: { alias: 0, rule: 1 }

  scope :pending, -> { where(accepted_at: nil, rejected_at: nil) }

  def pending?
    accepted_at.nil? && rejected_at.nil?
  end
end
