class CardStatementPayment < ApplicationRecord
  belongs_to :card_statement
  belongs_to :original_transaction, class_name: "Transaction", optional: true

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
  validates :original_transaction_id, uniqueness: true, allow_nil: true
  validates :description, uniqueness: { scope: %i[card_statement_id amount paid_at] }, allow_nil: true

  after_save :sync_card_statement_paid_amount
  after_destroy :sync_card_statement_paid_amount

  private

  def sync_card_statement_paid_amount
    card_statement.sync_paid_amount!
  end
end
