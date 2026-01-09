class Category < ApplicationRecord
  has_many :debts
  has_many :transactions
  
  validates :name, presence: true, uniqueness: true
end
