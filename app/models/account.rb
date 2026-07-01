class Account < ApplicationRecord
  belongs_to :user

  enum kind: {
    checking: 0,
    savings: 1,
    wallet: 2,
    digital_wallet: 3,
    other: 4
  }

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :kind, presence: true
  validates :initial_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :initial_balance_date, presence: true

  before_validation :normalize_name

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(:name) }

  def current_balance
    initial_balance.to_d
  end

  def archive!(archived_at_time: Time.current)
    update!(archived_at: archived_at_time)
  end

  def restore!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
