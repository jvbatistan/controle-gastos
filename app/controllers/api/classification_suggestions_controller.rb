class Api::ClassificationSuggestionsController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_suggestion, only: %i[accept reject correct]

  def index
    suggestions = current_user.classification_suggestions
                              .pending
                              .joins(:financial_transaction)
                              .merge(current_user.transactions.active)
                              .includes(:financial_transaction, :suggested_category)
                              .order(created_at: :desc)

    render json: suggestions.map { |suggestion| suggestion_json(suggestion) }
  end

  def accept
    transaction = @suggestion.financial_transaction

    if @suggestion.suggested_category_id.blank?
      return render json: { error: 'Suggestion has no suggested category' }, status: :unprocessable_entity
    end

    category = owned_category!(@suggestion.suggested_category_id)

    Transactions::ApplyClassificationService.call(
      suggestion: @suggestion,
      category: category,
      learn: true,
      mark_as: :accepted,
      alias_confidence: @suggestion.confidence
    )

    transaction.reload
    @suggestion.reload

    render json: suggestion_json(@suggestion), status: :ok
  end

  def reject
    transaction = @suggestion.financial_transaction
    category = owned_category!(transaction.category_id)

    Transaction.transaction do
      @suggestion.update!(rejected_at: Time.current)
      propagate_to_installment_group!(transaction, category, mark_as: :rejected)
    end

    transaction.reload
    @suggestion.reload

    render json: suggestion_json(@suggestion), status: :ok
  end

  def correct
    requested_category_id = params.dig(:classification_suggestion, :category_id)
    return render json: { error: 'category_id is required' }, status: :unprocessable_entity if requested_category_id.blank?

    transaction = @suggestion.financial_transaction
    category = owned_category!(requested_category_id)

    Transactions::ApplyClassificationService.call(
      suggestion: @suggestion,
      category: category,
      learn: true,
      mark_as: :rejected,
      alias_confidence: 1.0
    )

    transaction.reload
    @suggestion.reload

    render json: suggestion_json(@suggestion), status: :ok
  end

  private

  def set_suggestion
    @suggestion = current_user.classification_suggestions
                               .joins(:financial_transaction)
                               .merge(current_user.transactions.active)
                               .find(params[:id])
  end

  def owned_category!(category_id)
    return nil if category_id.blank?

    current_user.categories.find(category_id)
  end

  def propagate_to_installment_group!(transaction, category, mark_as:)
    gid = transaction.installment_group_id
    return 0 if gid.blank?

    Transactions::ApplyCategoryToInstallmentGroupService.new(
      transaction: transaction,
      category: category
    ).call

    tx_ids = transaction.user.transactions.where(installment_group_id: gid).pluck(:id)
    scope = current_user.classification_suggestions.pending.where(financial_transaction_id: tx_ids)
    now = Time.current

    if mark_as == :accepted
      scope.update_all(accepted_at: now, updated_at: now)
    else
      scope.update_all(rejected_at: now, updated_at: now)
    end
  end

  def suggestion_json(suggestion)
    transaction = suggestion.financial_transaction
    suggested_category = current_user.categories.find_by(id: suggestion.suggested_category_id)
    transaction_category = current_user.categories.find_by(id: transaction.category_id)

    {
      id: suggestion.id,
      confidence: suggestion.confidence,
      source: suggestion.source,
      accepted_at: suggestion.accepted_at,
      rejected_at: suggestion.rejected_at,
      suggested_category: suggested_category&.as_json(only: %i[id name]),
      financial_transaction: {
        id: transaction.id,
        description: transaction.description,
        date: transaction.date,
        value: transaction.value,
        kind: transaction.kind,
        category: transaction_category&.as_json(only: %i[id name]),
        installment_group_id: transaction.installment_group_id,
        installment_number: transaction.installment_number,
        installments_count: transaction.installments_count,
        classification_status: transaction.classification_status
      }
    }
  end
end
