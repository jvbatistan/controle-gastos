json.extract! debt, :id, :description, :value, :paid, :card_id, :created_at, :updated_at
json.url debt_url(debt, format: :json)
