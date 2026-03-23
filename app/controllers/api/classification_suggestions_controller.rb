class Api::ClassificationSuggestionsController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_suggestion, only: %i[accept reject correct]

  def index
    suggestions = current_user.classification_suggestions
                              .pending
                              .includes(:financial_transaction, :suggested_category)
                              .order(created_at: :desc)

    render json: suggestions.map { |suggestion| suggestion_json(suggestion) }
  end

  def accept
    category_id = @suggestion.suggested_category_id
    transaction = @suggestion.financial_transaction

    if category_id.blank?
      return render json: { error: 'Suggestion has no suggested category' }, status: :unprocessable_entity
    end

    Transaction.transaction do
      transaction.update!(category_id: category_id)
      @suggestion.update!(accepted_at: Time.current)

      propagate_to_installment_group!(transaction, category_id, mark_as: :accepted)

      Merchants::UpsertAliasService.new(
        user: current_user,
        description: transaction.description,
        category_id: category_id,
        confidence: @suggestion.confidence,
        source: :user_override
      ).call
    end

    transaction.reload
    @suggestion.reload

    render json: suggestion_json(@suggestion), status: :ok
  end

  def reject
    transaction = @suggestion.financial_transaction

    Transaction.transaction do
      @suggestion.update!(rejected_at: Time.current)
      propagate_to_installment_group!(transaction, transaction.category_id, mark_as: :rejected)
    end

    transaction.reload
    @suggestion.reload

    render json: suggestion_json(@suggestion), status: :ok
  end

  def correct
    category_id = params.dig(:classification_suggestion, :category_id)
    return render json: { error: 'category_id is required' }, status: :unprocessable_entity if category_id.blank?

    transaction = @suggestion.financial_transaction

    Transaction.transaction do
      transaction.update!(category_id: category_id)
      @suggestion.update!(rejected_at: Time.current)

      propagate_to_installment_group!(transaction, category_id, mark_as: :rejected)

      Merchants::UpsertAliasService.new(
        user: current_user,
        description: transaction.description,
        category_id: category_id,
        confidence: 1.0,
        source: :user_override
      ).call
    end

    transaction.reload
    @suggestion.reload

    render json: suggestion_json(@suggestion), status: :ok
  end

  private

  def set_suggestion
    @suggestion = current_user.classification_suggestions.find(params[:id])
  end

  def propagate_to_installment_group!(transaction, category_id, mark_as:)
    gid = transaction.installment_group_id
    return 0 if gid.blank?

    Transactions::ApplyCategoryToInstallmentGroupService.new(
      transaction: transaction,
      category_id: category_id
    ).call

    tx_ids = Transaction.where(installment_group_id: gid).pluck(:id)
    scope = ClassificationSuggestion.pending.where(financial_transaction_id: tx_ids)
    now = Time.current

    if mark_as == :accepted
      scope.update_all(accepted_at: now, updated_at: now)
    else
      scope.update_all(rejected_at: now, updated_at: now)
    end
  end

  def suggestion_json(suggestion)
    transaction = suggestion.financial_transaction

    {
      id: suggestion.id,
      confidence: suggestion.confidence,
      source: suggestion.source,
      accepted_at: suggestion.accepted_at,
      rejected_at: suggestion.rejected_at,
      suggested_category: suggestion.suggested_category&.as_json(only: %i[id name]),
      financial_transaction: {
        id: transaction.id,
        description: transaction.description,
        date: transaction.date,
        value: transaction.value,
        kind: transaction.kind,
        category: transaction.category&.as_json(only: %i[id name]),
        installment_group_id: transaction.installment_group_id,
        installment_number: transaction.installment_number,
        installments_count: transaction.installments_count,
        classification_status: transaction.classification_status
      }
    }
  end
end
