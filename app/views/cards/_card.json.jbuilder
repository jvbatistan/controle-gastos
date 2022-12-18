json.extract! card, :id, :name, :expiration, :created_at, :updated_at
json.url card_url(card, format: :json)
