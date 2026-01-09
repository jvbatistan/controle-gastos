class Debt < ApplicationRecord
  has_paper_trail
  
  belongs_to :card, optional: true
  belongs_to :category, optional: true

  validates :description, presence: true
  validates :value, presence: true
  validates :transaction_date, presence: true

  before_save :make_upcase
  before_save :set_expense_type
  before_destroy :destroy_all_installments
  
  before_validation :set_billing_statement, on: :create
  
  enum expense_type: { single: 0, recurring: 1, installment: 2 }

  def value=(val)
    if val.is_a?(String)
      val = val.gsub('.', '').tr(',', '.')
    end

    super(val)
  end

  def set_billing_statement
    DebtStatementService.new(self).call
  end

  private
    def destroy_all_installments
      if has_installment
        Debt.where(parent_id: self.id).destroy_all
      end
    end

    def make_upcase
      self.description = description.to_s.upcase.strip
      self.responsible = responsible.to_s.upcase.strip
    end

    def set_expense_type
      if has_installment
        self.expense_type = :installment
      elsif recurring_by_description?
        self.expense_type = :recurring
      else
        self.expense_type = :single
      end
    end

    def recurring_by_description?
      termos_recorrentes = ["academia", "internet", "brisanet", "spotify", "prime", "netflix", "crunchyroll", "streaming", "gym", "wi-fi", "plano", "claro"]
      termos_recorrentes.any? { |termo| description.to_s.downcase.include?(termo) }
    end
end
