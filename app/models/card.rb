class Card < ApplicationRecord
  has_many :debts, dependent: :destroy

  validates :name, :due_date, :closing_date, presence: true

  before_save :make_upcase

  private

  def make_upcase
    self.name = self.name.upcase.strip
  end
end
