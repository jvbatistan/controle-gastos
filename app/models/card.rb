class Card < ApplicationRecord
  has_many :debts, dependent: :destroy

  validates :name, :due_date, :closing_date, presence: true

  before_save :make_upcase

  scope :ordenados, -> {
    order(Arel.sql("CASE WHEN name LIKE 'outros' THEN 1 ELSE 0 END"), :name)
  }

  def debts_by_date(month = Date.today.month, year = Date.today.year)
    # debts.where("strftime('%m', billing_statement) = ? AND strftime('%Y', billing_statement) = ?", month.to_s.rjust(2, '0'), year.to_s).order(:transaction_date, :description, :value, :responsible)
    debts.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).order(:transaction_date, :description, :value, :responsible)
  end

  def total_debt(month = Date.today.month, year = Date.today.year)
    # debts.where("strftime('%m', billing_statement) = ? AND strftime('%Y', billing_statement) = ?", month.to_s.rjust(2, '0'), year.to_s).sum(:value)
    debts.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).sum(:value)
  end

  def self.with_totals(month = Date.today.month, year = Date.today.year)
    left_joins(:debts)
      .select("cards.*, COALESCE(SUM(debts.value), 0) AS total_value")
      .where("EXTRACT(MONTH FROM debts.billing_statement) = ? AND EXTRACT(YEAR FROM debts.billing_statement) = ? OR debts.id IS NULL", month, year)
      .where("debts.paid = ?", false)
      .group("cards.id")
      .order("total_value DESC")
  end

   def self.total_sum_for(month = Date.today.month, year = Date.today.year)
    joins(:debts)
      .where("EXTRACT(MONTH FROM debts.billing_statement) = ? AND EXTRACT(YEAR FROM debts.billing_statement) = ?", month, year)
      .where("debts.paid = ?", false)
      .sum(:value)
  end

  private

  def make_upcase
    self.name = self.name.upcase.strip
  end
end
