class Api::TransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_transaction, only: [:update, :destroy]

  def index
    scope = current_user.transactions.includes(:category, :card).order(date: :desc, id: :desc)

    month   = params[:month].presence
    year    = params[:year].presence
    card_id = params[:card_id].presence

    if card_id.present?
      if card_id == "none"
        scope = scope.where(card_id: nil)
      elsif current_user.cards.exists?(card_id)
        scope = scope.where(card_id: card_id)
      else
        scope = scope.none
      end
    end

    if month.present? && year.present?
      month_i = month.to_i
      year_i  = year.to_i

      begin
        start_date = Date.new(year_i, month_i, 1)
        end_date   = start_date.end_of_month
      rescue Date::Error
        scope = scope.none
        start_date = nil
        end_date = nil
      end

      if start_date && end_date
        if card_id.blank?
          scope = scope.where(
            "(card_id IS NOT NULL AND billing_statement >= ? AND billing_statement <= ?) OR (card_id IS NULL AND date >= ? AND date <= ?)",
            start_date, end_date, start_date, end_date
          )
        elsif card_id == "none"
          scope = scope.where(date: start_date..end_date)
        else
          scope = scope.where(billing_statement: start_date..end_date)
        end
      end
    end

    limit = params[:limit].presence&.to_i || 50
    limit = 200 if limit > 200
    scope = scope.limit(limit)

    render json: scope.as_json(
      only: [:id, :description, :value, :date, :kind, :source, :paid, :installment_number, :installments_count],
      methods: [],
      include: {
        category: { only: [:id, :name] },
        card: { only: [:id, :name] }
      }
    )
  end

  def create
    transaction = current_user.transactions.new(transaction_params)

    if transaction.save
      render json: tx_json(transaction), status: :created
    else
      render json: { error: transaction.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update
    if @transaction.update(transaction_params)
      render json: tx_json(@transaction), status: :ok
    else
      render json: { error: @transaction.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    head :no_content
  end

  private

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(
      :description, :value, :date, :kind, :source, :paid,
      :note, :responsible, :card_id, :category_id, :billing_statement
    )
  end

  def tx_json(transaction)
    transaction.as_json(
      only: [:id, :description, :value, :date, :kind, :source, :paid, :installment_number, :installments_count],
      include: {
        category: { only: [:id, :name] },
        card: { only: [:id, :name] }
      }
    )
  end
end
