class AccountTransfer < ApplicationRecord
  belongs_to :user
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account"

  enum status: {
    completed: 0,
    reversed: 1
  }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transferred_on, presence: true

  validate :accounts_must_be_distinct
  validate :accounts_must_belong_to_user
  validate :accounts_must_be_active_for_new_transfer

  before_validation :normalize_text_fields

  scope :ordered, -> { order(transferred_on: :desc, id: :desc) }

  private

  def normalize_text_fields
    self.description = description.to_s.strip.presence
    self.note = note.to_s.strip.presence
  end

  def accounts_must_be_distinct
    return if from_account_id.blank? || to_account_id.blank?
    return if from_account_id != to_account_id

    errors.add(:to_account, "deve ser diferente da conta de origem")
  end

  def accounts_must_belong_to_user
    return if user.blank?

    if from_account.present? && from_account.user_id != user_id
      errors.add(:from_account, "deve pertencer ao usuário")
    end

    if to_account.present? && to_account.user_id != user_id
      errors.add(:to_account, "deve pertencer ao usuário")
    end
  end

  def accounts_must_be_active_for_new_transfer
    if from_account.present? && account_must_be_active?(:from_account_id) && from_account.archived?
      errors.add(:from_account, "não pode estar arquivada")
    end

    if to_account.present? && account_must_be_active?(:to_account_id) && to_account.archived?
      errors.add(:to_account, "não pode estar arquivada")
    end
  end

  def account_must_be_active?(attribute)
    new_record? || public_send("will_save_change_to_#{attribute}?")
  end
end
