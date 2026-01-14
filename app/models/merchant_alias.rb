class MerchantAlias < ApplicationRecord
  belongs_to :category

  enum source: { user_override: 0, seed: 1 }

  validates :normalized_merchant, presence: true, uniqueness: true
end
