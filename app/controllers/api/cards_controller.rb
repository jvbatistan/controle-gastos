class Api::CardsController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_card, only: [:update, :destroy]

  def index
    cards = current_user.cards.ordenados

    render json: cards.map { |card| card_json(card) }
  end

  def create
    card = current_user.cards.new(card_params)

    if card.save
      render json: card_json(card), status: :created
    else
      render json: { error: card.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update
    if @card.update(card_params)
      render json: card_json(@card), status: :ok
    else
      render json: { error: @card.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    if @card.in_use?
      render json: { error: 'Cartão em uso e não pode ser removido' }, status: :unprocessable_entity
      return
    end

    if @card.destroy
      head :no_content
    else
      render json: { error: @card.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def set_card
    @card = current_user.cards.find(params[:id])
  end

  def card_params
    params.require(:card).permit(:name, :due_day, :closing_day, :limit)
  end

  def card_json(card)
    {
      id: card.id,
      name: card.name,
      due_day: card.due_day_value,
      closing_day: card.closing_day_value,
      limit: card.limit
    }
  end
end
