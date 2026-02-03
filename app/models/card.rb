class Card < ApplicationRecord
  has_many :transactions, dependent: :nullify

  validates :name, :due_date, :closing_date, presence: true

  before_save :make_upcase

  scope :ordenados, -> {
    order(Arel.sql("CASE WHEN name LIKE 'outros' THEN 1 ELSE 0 END"), :name)
  }

  def transactions_by_date(month = Date.today.month, year = Date.today.year)
    transactions.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).order(date: :desc, value: :desc, description: :asc)
  end

  def total_transactions(month = Date.today.month, year = Date.today.year)
    transactions.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).where(paid: false).sum(:value)
  end

  def self.with_totals(month = Date.today.month, year = Date.today.year)
    left_joins(:transactions).select("cards.*, COALESCE(SUM(transactions.value), 0) AS total_value").where("(EXTRACT(MONTH FROM transactions.billing_statement) = ? AND EXTRACT(YEAR FROM transactions.billing_statement) = ?) OR transactions.id IS NULL", month, year).where("transactions.paid = ? OR transactions.id IS NULL", false).group("cards.id").order("total_value DESC")
  end

  def self.total_sum_for(month = Date.today.month, year = Date.today.year)
    joins(:transactions).where("EXTRACT(MONTH FROM transactions.billing_statement) = ? AND EXTRACT(YEAR FROM transactions.billing_statement) = ?", month, year).where(transactions: { paid: false }).sum("transactions.value")
  end

  private

  def make_upcase
    self.name = self.name.upcase.strip
  end
end
