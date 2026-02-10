class CardStatement < ApplicationRecord
  belongs_to :card

  validates :billing_statement, presence: true
  validates :total_amount, :paid_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validates :billing_statement, uniqueness: { scope: :card_id }

  def remaining_amount
    [total_amount.to_d - paid_amount.to_d, 0.to_d].max
  end

  def paid?
    remaining_amount <= 0
  end

  def apply_payment!(value, paid_at: Time.zone.now)
    v = value.to_d
    raise ArgumentError, "Pagamento deve ser > 0" if v <= 0

    self.paid_amount = paid_amount.to_d + v

    became_paid = !paid_at.present? && (total_amount.to_d - self.paid_amount.to_d) <= 0

    # se quitou agora, marca paid_at (se ainda não tinha)
    self.paid_at ||= paid_at if paid?
    save!

    mark_transactions_as_paid! if paid?
  end

  def mark_transactions_as_paid!
    start_date = Date.new(billing_statement.year, billing_statement.month, 1)
    end_date   = start_date.end_of_month
    if card_id.present?
      Transaction.where("card_id = ? AND billing_statement >= ? AND billing_statement <= ? and paid IS false", card_id, start_date, end_date).update_all(paid: true, updated_at: Time.current)
    else
      Transaction.where("card_id IS NULL AND date >= ? AND date <= ? and paid IS false", start_date, end_date).update_all(paid: true, updated_at: Time.current)
    end
  end
end
