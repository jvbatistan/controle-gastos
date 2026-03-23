class Api::TransactionsController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_transaction, only: %i[update destroy]

  def index
    scope = current_user.transactions.includes(:category, :card, :classification_suggestions).order(date: :desc, id: :desc)

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

    render json: scope.limit(limit).map { |transaction| tx_json(transaction) }
  end

  def create
    transaction = current_user.transactions.new(transaction_params)

    unless valid_card_and_category_owner?(transaction)
      return render json: { error: transaction.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    if transaction.save
      Transactions::CreateCategorySuggestionService.new(transaction).call if transaction.category_id.blank?
      transaction.reload

      render json: tx_json(transaction), status: :created
    else
      render json: { error: transaction.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update
    @transaction.assign_attributes(transaction_params)

    unless valid_card_and_category_owner?(@transaction)
      return render json: { error: @transaction.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    if @transaction.save
      @transaction.reload
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

  def valid_card_and_category_owner?(transaction)
    if transaction.card_id.present? && !current_user.cards.exists?(transaction.card_id)
      transaction.errors.add(:card, 'inválido')
    end

    if transaction.category_id.present? && !current_user.categories.exists?(transaction.category_id)
      transaction.errors.add(:category, 'inválida')
    end

    transaction.errors.empty?
  end

  def tx_json(transaction)
    suggestion = transaction.pending_classification_suggestion

    {
      id: transaction.id,
      description: transaction.description,
      value: transaction.value,
      date: transaction.date,
      kind: transaction.kind,
      source: transaction.source,
      paid: transaction.paid,
      note: transaction.note,
      responsible: transaction.responsible,
      billing_statement: transaction.billing_statement,
      installment_number: transaction.installment_number,
      installments_count: transaction.installments_count,
      classification: {
        status: transaction.classification_status,
        category: transaction.category&.as_json(only: %i[id name]),
        suggestion: suggestion_json(suggestion)
      },
      category: transaction.category&.as_json(only: %i[id name]),
      card: transaction.card&.as_json(only: %i[id name])
    }
  end

  def suggestion_json(suggestion)
    return nil if suggestion.nil?

    {
      id: suggestion.id,
      confidence: suggestion.confidence,
      source: suggestion.source,
      suggested_category: suggestion.suggested_category&.as_json(only: %i[id name])
    }
  end
end
