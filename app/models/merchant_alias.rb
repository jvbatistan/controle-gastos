class MerchantAlias < ApplicationRecord
  belongs_to :category
  belongs_to :user

  enum source: { user_override: 0, seed: 1 }

  validates :normalized_merchant, presence: true, uniqueness: { scope: :user_id }
end
