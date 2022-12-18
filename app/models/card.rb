class Card < ApplicationRecord
  has_many :spends, dependent: :destroy

  validates :name, presence: true
  validates :expiration, presence: true
end
