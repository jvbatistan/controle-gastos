class Category < ApplicationRecord
  belongs_to :user

  has_many :debts
  has_many :transactions
  has_many :merchant_aliases, dependent: :restrict_with_error
  has_many :classification_suggestions, foreign_key: :suggested_category_id, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :user_id }

  def in_use?
    transactions.exists? || merchant_aliases.exists? || classification_suggestions.exists?
  end
end
