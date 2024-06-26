json.extract! expense, :id, :description, :value, :paid, :card_id, :created_at, :updated_at
json.url expense_url(expense, format: :json)
