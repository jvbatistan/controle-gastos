class Debt < ApplicationRecord
  belongs_to :card, optional: true

  validates :description, presence: true
  validates :value, presence: true
  validates :transaction_date, presence: true

  before_save :make_upcase
  before_save :belongs_next_statement
  after_create :next_installments
  before_destroy :destroy_all_installments

  private
    def next_installments
      if has_installment
        if (current_installment.to_i < final_installment.to_i)
          next_debt = self.dup
          
          next_debt.transaction_date     = next_debt.transaction_date + 1.month
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

    def make_upcase
      self.description = self.description.upcase.strip
      self.responsible = self.responsible.upcase.strip
    end

    def belongs_next_statement
      month = self.transaction_date.month
      year  = self.transaction_date.year

      # Calcula a data de fechamento da fatura
      if month == 12
        closing_date = Date.new(year + 1, 1, self.card.due_date) - self.card.closing_date
      else
        closing_date = Date.new(year, month, self.card.due_date) - self.card.closing_date
      end

      # Se a compra foi feita no dia do fechamento ou depois, cai na fatura do mês seguinte
      if self.transaction_date >= closing_date
        due_date = closing_date + 1.month + self.card.closing_date
      else
        due_date = closing_date + self.card.closing_date
      end
      
      self.billing_statement = due_date
    end
end
