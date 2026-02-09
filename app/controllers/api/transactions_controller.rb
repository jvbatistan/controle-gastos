class Api::TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    transactions = current_user.transactions
      .includes(:category, :card)
      .order(date: :desc, created_at: :desc)
      .limit(200)

    render json: transactions.as_json(
      only: [:id, :description, :value, :date, :kind, :source, :paid],
      methods: [],
      include: {
        category: { only: [:id, :name] },
        card: { only: [:id, :name] }
      }
    )
  end
end
