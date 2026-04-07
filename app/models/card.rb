class Card < ApplicationRecord
  belongs_to :user

  has_many :transactions, dependent: :nullify
  has_many :card_statements, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :limit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :validate_due_day_presence
  validate :validate_closing_day_presence
  validate :validate_due_day_range
  validate :validate_closing_day_range

  before_validation :normalize_attributes

  scope :ordenados, -> {
    order(Arel.sql("CASE WHEN name LIKE 'outros' THEN 1 ELSE 0 END"), :name)
  }
  scope :with_totals, ->(month = Date.today.month, year = Date.today.year) {
    joins(
      ApplicationRecord.sanitize_sql_array([
        "LEFT JOIN transactions active_transactions ON active_transactions.card_id = cards.id AND active_transactions.archived_at IS NULL AND EXTRACT(MONTH FROM active_transactions.billing_statement) = ? AND EXTRACT(YEAR FROM active_transactions.billing_statement) = ?",
        month,
        year
      ])
    )
      .select("cards.*, COALESCE(SUM(active_transactions.value), 0) AS total_value")
      .group("cards.id")
      .order("total_value DESC")
  }

  scope :total_sum_for, ->(month = Date.today.month, year = Date.today.year) {
    joins(:transactions)
      .merge(Transaction.active)
      .where("EXTRACT(MONTH FROM transactions.billing_statement) = ? AND EXTRACT(YEAR FROM transactions.billing_statement) = ?", month, year)
      .where(transactions: { paid: false })
      .sum("transactions.value")
  }

  def transactions_by_date(month = Date.today.month, year = Date.today.year)
    transactions.active.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).order(date: :desc, value: :desc, description: :asc)
  end

  def total_transactions(month = Date.today.month, year = Date.today.year)
    transactions.active.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).where(paid: false).sum(:value)
  end

  def month_total(month, year)
    transactions.active.where("EXTRACT(MONTH FROM billing_statement) = ? AND EXTRACT(YEAR FROM billing_statement) = ?", month, year).sum(:value)
  end

  def statement_for(month, year)
    bs = due_on(year.to_i, month.to_i)
    card_statements.find_or_create_by!(billing_statement: bs)
  end

  def sync_statement!(month, year)
    st = statement_for(month, year)

    total = month_total(month, year).to_d

    if st.total_amount.to_d != total
      st.update!(total_amount: total)
    end

    st
  end

  def in_use?
    transactions.exists? || card_statements.exists?
  end

  def uses_calendar_cycle?
    due_day.present? && closing_day.present?
  end

  def due_day_value
    due_day.presence || due_date
  end

  def closing_day_value(reference_date = Date.current)
    return closing_day if closing_day.present?
    return nil unless due_date.present? && closing_date.present?

    legacy_closing_on(reference_date.year, reference_date.month).day
  end

  def due_on(year, month)
    clamp_day_of_month(year, month, due_day_value)
  end

  def closing_on(year, month)
    return clamp_day_of_month(year, month, closing_day) if closing_day.present?

    legacy_closing_on(year, month)
  end

  private

  def normalize_attributes
    self.name = name.to_s.upcase.strip
    self.due_day ||= due_date if due_date.present?
  end

  def validate_due_day_presence
    return if due_day_value.present?

    errors.add(:due_day, 'não pode ficar em branco')
  end

  def validate_closing_day_presence
    return if closing_day.present? || closing_date.present?

    errors.add(:closing_day, 'não pode ficar em branco')
  end

  def validate_due_day_range
    return if due_day_value.blank?
    return if due_day_value.between?(1, 31)

    errors.add(:due_day, 'deve estar entre 1 e 31')
  end

  def validate_closing_day_range
    value = closing_day.presence || closing_date
    return if value.blank?
    return if value.between?(1, 31)

    errors.add(:closing_day, 'deve estar entre 1 e 31')
  end

  def legacy_closing_on(year, month)
    legacy_due_on = clamp_day_of_month(year, month, due_date)
    legacy_due_on - closing_date
  end

  def clamp_day_of_month(year, month, day)
    last_day = Date.civil(year, month, -1).day
    Date.new(year, month, [day.to_i, last_day].min)
  end
end
