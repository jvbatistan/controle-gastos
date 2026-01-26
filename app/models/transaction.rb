class Transaction < ApplicationRecord
  belongs_to :card, optional: true
  belongs_to :category, optional: true

  has_one :debt, foreign_key: :financial_transaction_id, dependent: :destroy
  accepts_nested_attributes_for :debt, update_only: true, allow_destroy: true
  attr_accessor :has_installments

  has_many :classification_suggestions, foreign_key: :financial_transaction_id, dependent: :destroy

  enum kind: { income: 0, expense: 1 }
  enum source: { card: 0, cash: 1, bank: 2 }

  validates :description, presence: true
  validates :date,        presence: true
  validates :kind,        presence: true
  validates :source,      presence: true
  validates :value,       presence: true,
                          numericality: { greater_than: 0 }

  before_validation :normalize_strings

  after_commit :create_category_suggestion, on: [:create, :update]

  scope :by_month, ->(month, year) { where("EXTRACT(MONTH FROM date) = ? AND EXTRACT(YEAR FROM date) = ?", month, year) }
  scope :by_period, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_card, ->(card_id) { where(card_id: card_id) if card_id.present? }
  scope :by_category, ->(category_id) { where(category_id: category_id) if category_id.present? }
  scope :by_paid, ->(paid) { return all if paid.nil? where(paid: ActiveRecord::Type::Boolean.new.cast(paid)) }
  scope :expenses, -> { where(kind: kinds[:expense]) }
  scope :incomes,  -> { where(kind: kinds[:income]) }

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
      val = val.gsub('.', '').tr(',', '.')
    end

    super(val)
  end

  private

  def normalize_strings
    self.description = description.to_s.upcase.strip
    self.responsible = responsible.to_s.upcase.strip
  end

  def create_category_suggestion
    return if destroyed?
    return if category_id.present?

    return unless previous_changes.key?("id") || previous_changes.key?("description")

    Transactions::CreateCategorySuggestionService.new(self).call
  end
end
