class Debt < ApplicationRecord
  has_paper_trail
  
  belongs_to :financial_transaction, class_name: 'Transaction', optional: true

  validates :current_installment, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :final_installment, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validate :current_cannot_be_greater_than_final

  private
  def current_cannot_be_greater_than_final
    return if current_installment.blank? || final_installment.blank?

    if current_installment > final_installment
      errors.add(:current_installment, "cannot be greater than final installment")
    end
  end
end
