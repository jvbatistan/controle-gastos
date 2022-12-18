class Spend < ApplicationRecord
  belongs_to :card, optional: true

  validates :description, presence: true
  validates :value, presence: true
  validates :month, presence: true
  validates :year, presence: true
end
