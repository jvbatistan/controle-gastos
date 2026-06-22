class CardStatement < ApplicationRecord
  belongs_to :card
  has_many :card_statement_payments, dependent: :destroy

  validates :billing_statement, presence: true
  validates :total_amount, presence: true, numericality: true
  validates :paid_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validates :billing_statement, uniqueness: { scope: :card_id }

  scope :active_for_payments, -> { where(ignored_at: nil) }

  def remaining_amount
    [total_amount.to_d - paid_amount.to_d, 0.to_d].max
  end

  def paid?
    remaining_amount <= 0
  end

  def ignored?
    ignored_at.present?
  end

  def ignore_for_payment!(ignored_at_time: Time.zone.now)
    update!(ignored_at: ignored_at_time)
  end

  def apply_payment!(value, paid_at: Time.zone.now)
    v = value.to_d
    raise ArgumentError, "Pagamento deve ser > 0" if v <= 0

    card_statement_payments.create!(
      amount: v,
      paid_at: paid_at,
      description: "Pagamento da fatura",
      source: "manual"
    )

    reload

    mark_transactions_as_paid! if paid?
  end

  def sync_paid_amount!
    paid_total = card_statement_payments.sum(:amount).to_d
    latest_paid_at = card_statement_payments.maximum(:paid_at)
    next_paid_at = paid_total >= total_amount.to_d && total_amount.to_d.positive? ? latest_paid_at : nil

    update_columns(
      paid_amount: paid_total,
      paid_at: next_paid_at,
      updated_at: Time.current
    )
  end

  def mark_transactions_as_paid!
    start_date = Date.new(billing_statement.year, billing_statement.month, 1)
    end_date   = start_date.end_of_month
    if card_id.present?
      Transaction.active.where("card_id = ? AND billing_statement >= ? AND billing_statement <= ? and paid IS false", card_id, start_date, end_date).update_all(paid: true, updated_at: Time.current)
    else
      Transaction.active.where("card_id IS NULL AND date >= ? AND date <= ? and paid IS false", start_date, end_date).update_all(paid: true, updated_at: Time.current)
    end
  end
end
