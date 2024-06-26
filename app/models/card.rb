class Card < ApplicationRecord
  has_many :expenses, dependent: :destroy

  validates :name, :pay_day, presence: true
end
