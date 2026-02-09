class Transaction < ApplicationRecord
  belongs_to :card, optional: true
  belongs_to :category, optional: true
  belongs_to :user
  
  has_many :classification_suggestions, foreign_key: :financial_transaction_id, dependent: :destroy

  enum kind: { income: 0, expense: 1 }
  enum source: { card: 0, cash: 1, bank: 2 }

  validates :description, presence: true
  validates :date,        presence: true
  validates :kind,        presence: true
  validates :source,      presence: true
  validates :value,       presence: true, numericality: { greater_than: 0 }
  validates :installment_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :installments_count, numericality: { only_integer: true, greater_than: 1 }, allow_nil: true

  validate :installment_consistency

  before_validation :normalize_strings
  before_validation :set_billing_statement, if: -> { card_id.present? && date.present? }

  after_create_commit :create_category_suggestion
  after_update_commit :create_category_suggestion, if: -> { saved_change_to_description? }

  scope :by_month,          -> (month, year)          { where("EXTRACT(MONTH FROM date) = ? AND EXTRACT(YEAR FROM date) = ?", month, year) }
  scope :by_period,         -> (start_date, end_date) { where(date: start_date..end_date) }
  scope :by_card,           -> (card_id)              { where(card_id: card_id) if card_id.present? }
  scope :by_category,       -> (category_id)          { where(category_id: category_id) if category_id.present? }
  scope :by_paid,           -> (paid) do
                                        return all if paid.nil? 
                                        where(paid: ActiveRecord::Type::Boolean.new.cast(paid)) 
                                      end
  scope :expenses,          ->                        { where(kind: kinds[:expense]) }
  scope :incomes,           ->                        { where(kind: kinds[:income]) }
  scope :installments_only, ->                        { where.not(installment_group_id: nil) }
  scope :non_installments,  ->                        { where(installment_group_id: nil) }

  def installment?
    installment_group_id.present?
  end

  def installment_label
    return nil unless installment?
    "#{installment_number}/#{installments_count}"
  end

  def installment_siblings
    return Transaction.none unless installment?
    Transaction.where(installment_group_id: installment_group_id).order(:installment_number)
  end

  def self.total_for_month(month = Date.today.month, year = Date.today.year)
    by_month(month, year).sum(:value)
  end

  def self.expenses_total_for(month = Date.today.month, year = Date.today.year)
    expenses.by_month(month, year).sum(:value)
  end

  def self.incomes_total_for(month = Date.today.month, year = Date.today.year)
    incomes.by_month(month, year).sum(:value)
  end

  def self.balance_for(month = Date.today.month, year = Date.today.year)
    incomes_total_for(month, year) - expenses_total_for(month, year)
  end

  def value=(val)
    if val.is_a?(String)
      s = val.strip

      if s.include?(",")
        s = s.gsub(".", "").tr(",", ".")
      end

      val = s
    end

    super(val)
  end

  def set_billing_statement
    BillingStatementService.new(self).call
  end

  private

  def normalize_strings
    self.description = description.to_s.upcase.strip
    self.responsible = responsible.to_s.upcase.strip
  end

  def create_category_suggestion
    return if destroyed?
    return if category_id.present?

    Transactions::CreateCategorySuggestionService.new(self).call
  end

  def installment_consistency
    if installment_group_id.present?
      errors.add(:installment_number, "é obrigatório quando parcelado") if installment_number.blank?
      errors.add(:installments_count, "é obrigatório quando parcelado") if installments_count.blank?
    else
      if installment_number.present? || installments_count.present?
        errors.add(:base, "campos de parcela não podem existir sem installment_group_id")
      end
    end
  end
end
