class Card < ApplicationRecord
  has_many :debts, dependent: :destroy

  validates :name, :due_date, :closing_date, presence: true

  before_save :make_upcase

  def debts_by_date(month = Date.today.month, year = Date.today.year)
    debts.where("strftime('%m', billing_statement) = ? AND strftime('%Y', billing_statement) = ?", month.to_s.rjust(2, '0'), year.to_s).order(:transaction_date, :description, :value, :responsible)
  end

  def total_debt(month = Date.today.month, year = Date.today.year)
    debts.where("strftime('%m', billing_statement) = ? AND strftime('%Y', billing_statement) = ?", month.to_s.rjust(2, '0'), year.to_s).sum(:value)
  end

  private

  def make_upcase
    self.name = self.name.upcase.strip
  end
end
