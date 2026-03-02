class Api::CardsController < ApplicationController
  before_action :authenticate_user!

  def index
    cards = current_user.cards.ordenados

    render json: cards.as_json(only: [:id, :name])
  end
end
