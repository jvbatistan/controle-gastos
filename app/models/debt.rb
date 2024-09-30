class Debt < ApplicationRecord
  belongs_to :card, optional: true

  validates :description, presence: true
  validates :value, presence: true
  validates :month, presence: true
  validates :year, presence: true

  after_create :next_installments
  before_destroy :destroy_all_installments

  private
    def next_installments
      if has_installment
        if (current_installment.to_i < final_installment.to_i)
          next_debt = self.dup
          
          if (month.to_i + 1) < 13
            next_debt.month = (month.to_i + 1).to_s.rjust(2, '0')
          else
            next_debt.month = "01"
            next_debt.year = (year.to_i + 1).to_s
          end
          
          next_debt.current_installment += 1
          
          unless parent_id.present?
            next_debt.parent_id = self.id
          end

          next_debt.save!
        end
      end
    end

    def destroy_all_installments
      if has_installment
        Debt.where(parent_id: self.id).destroy_all
      end
    end
end
