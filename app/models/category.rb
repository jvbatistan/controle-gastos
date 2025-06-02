class Category < ApplicationRecord
  has_many :debts
  validates :name, presence: true, uniqueness: true
end
