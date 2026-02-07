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

    # se quitou agora, marca paid_at (se ainda não tinha)
    self.paid_at ||= paid_at if paid?

    save!
  end
end
