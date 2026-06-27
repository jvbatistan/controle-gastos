class MerchantAlias < ApplicationRecord
  belongs_to :category
  belongs_to :user

  enum source: { user_override: 0, seed: 1 }

  validates :normalized_merchant, presence: true, uniqueness: { scope: :user_id }
  validate :category_must_belong_to_user

  private

  def category_must_belong_to_user
    return if category.nil? || user.nil?
    return if category.user_id == user_id

    errors.add(:category, 'deve pertencer ao mesmo usuário')
  end
end
