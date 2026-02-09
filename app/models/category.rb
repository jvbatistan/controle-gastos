class Category < ApplicationRecord
  belongs_to :user
  
  has_many :debts
  has_many :transactions
  
  validates :name, presence: true, uniqueness: true
end
