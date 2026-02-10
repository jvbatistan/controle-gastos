class Card < ApplicationRecord
  belongs_to :user
  
  has_many :transactions, dependent: :nullify
  has_many :card_statements, dependent: :destroy

  validates :name, :due_date, :closing_date, presence: true

  before_save :make_upcase

  scope :ordenados, -> {
    order(Arel.sql("CASE WHEN name LIKE 'outros' THEN 1 ELSE 0 END"), :name)
  }
  scope :with_totals, -> (month = Date.today.month, year = Date.today.year) {
    left_joins(:transactions)
      .select("cards.*, COALESCE(SUM(transactions.value), 0) AS total_value")
      .where("(EXTRACT(MONTH FROM transactions.billing_statement) = ? AND EXTRACT(YEAR FROM transactions.billing_statement) = ?) OR transactions.id IS NULL", month, year)
      .group("cards.id")
      .order("total_value DESC")
  }

  scope :total_sum_for, -> (month = Date.today.month, year = Date.today.year) {
    joins(:transactions)
      .where("EXTRACT(MONTH FROM transactions.billing_statement) = ? AND EXTRACT(YEAR FROM transactions.billing_statement) = ?", month, year)
      .where(transactions: { paid: false })
      .sum("transactions.value")
  }
  
  def transactions_by_date(month = Date.today.month, year = Date.today.year)
    transactions.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).order(date: :desc, value: :desc, description: :asc)
  end

  def total_transactions(month = Date.today.month, year = Date.today.year)
    transactions.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).where(paid: false).sum(:value)
  end

  def month_total(month, year)
    transactions.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).sum(:value)
  end

  def statement_for(month, year)
    bs = Date.new(year.to_i, month.to_i, due_date)
    card_statements.find_or_create_by!(billing_statement: bs)
  end

  def sync_statement!(month, year)
    st = statement_for(month, year)

    total = month_total(month, year).to_d

    # só atualiza se mudou (evita update atoa)
    if st.total_amount.to_d != total
      st.update!(total_amount: total)
    end

    st
  end

  private

  def make_upcase
    self.name = self.name.upcase.strip
  end
end
