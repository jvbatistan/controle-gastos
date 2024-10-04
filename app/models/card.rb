class Card < ApplicationRecord
  has_many :debts, dependent: :destroy

  validates :name, :due_date, :closing_date, presence: true
end
