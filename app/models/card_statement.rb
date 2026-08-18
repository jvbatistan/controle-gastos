class CardStatement < ApplicationRecord
  class PaymentExceedsRemainingAmount < ArgumentError; end
  class AlreadyPaid < ArgumentError; end

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

  def apply_payment!(value, account:, paid_at: Time.zone.now)
    raise ArgumentError, "Conta é obrigatória para pagar fatura." if account.blank?

    v = value.to_d

    with_lock do
      sync_paid_amount!

      available_amount = remaining_amount
      raise AlreadyPaid, "Fatura já está quitada." if available_amount <= 0
      raise ArgumentError, "Pagamento deve ser > 0" if v <= 0
      if v > available_amount
        raise PaymentExceedsRemainingAmount, "Pagamento excede o saldo restante da fatura. Saldo atual: #{format_decimal(available_amount)}"
      end

      card_statement_payments.create!(
        amount: v,
        paid_at: paid_at,
        description: "Pagamento da fatura",
        source: "manual",
        account: account
      )

      reload

      mark_transactions_as_paid! if paid?
    end
  end

  def sync_paid_amount!
    paid_total = card_statement_payments.sum(:amount).to_d
    latest_paid_at = card_statement_payments.maximum(:paid_at)
    sync_totals!(total_amount: total_amount, paid_amount: paid_total, latest_paid_at: latest_paid_at)
  end

  def sync_totals!(total_amount:, paid_amount:, latest_paid_at:)
    next_total_amount = total_amount.to_d
    next_paid_amount = paid_amount.to_d
    next_paid_at = next_paid_amount >= next_total_amount && next_total_amount.positive? ? latest_paid_at : nil
    changes = {}
    changes[:total_amount] = next_total_amount if self.total_amount.to_d != next_total_amount
    changes[:paid_amount] = next_paid_amount if self.paid_amount.to_d != next_paid_amount
    changes[:paid_at] = next_paid_at if paid_at != next_paid_at

    update_columns(changes.merge(updated_at: Time.current)) if changes.any?
    self
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

  def format_decimal(value)
    value.to_d.to_s("F")
  end
end
