class Card < ApplicationRecord
  has_many :debts, dependent: :destroy

  validates :name, :pay_day, presence: true
end
