class Api::ClassificationSuggestionsController < Api::BaseController
  UNSET = Object.new.freeze

  before_action :authenticate_user!
  before_action :set_suggestion, only: %i[apply accept reject correct]

  def index
    scope = current_user.classification_suggestions
                              .pending
                              .joins(:financial_transaction)
                              .merge(current_user.transactions.active)
                              .includes(:suggested_category, financial_transaction: :category)
                              .order(created_at: :desc)
    total_count = scope.count
    suggestions = scope.offset((pagination_page - 1) * pagination_per_page).limit(pagination_per_page)
    pending_suggestions = pending_suggestions_for(suggestions)

    render json: {
      suggestions: suggestions.map do |suggestion|
        suggestion_json(suggestion, pending_suggestion: pending_suggestions[suggestion.financial_transaction_id])
      end,
      pagination: pagination_json(total_count)
    }
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

  def apply
    requested_category_id = params[:category_id]
    return render json: { error: 'category_id is required' }, status: :unprocessable_entity if requested_category_id.blank?

    learn = parsed_learn_param
    return render json: { error: 'learn is required' }, status: :unprocessable_entity if learn == :missing
    return render json: { error: 'learn must be a boolean' }, status: :unprocessable_entity if learn == :invalid

    transaction = @suggestion.financial_transaction
    category = owned_category!(requested_category_id)

    Transactions::ApplyClassificationService.call(
      suggestion: @suggestion,
      category: category,
      learn: learn,
      mark_as: :accepted,
      alias_confidence: 1.0
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

  def parsed_learn_param
    return :missing unless params.key?(:learn)
    return params[:learn] if params[:learn] == true || params[:learn] == false

    case params[:learn].to_s.strip.downcase
    when 'true', '1'
      true
    when 'false', '0'
      false
    else
      :invalid
    end
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

  def suggestion_json(suggestion, pending_suggestion: UNSET)
    transaction = suggestion.financial_transaction
    suggested_category = suggestion.suggested_category
    transaction_category = transaction.category

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
        classification_status: classification_status(transaction, pending_suggestion)
      }
    }
  end

  def pending_suggestions_for(suggestions)
    transactions = suggestions.map(&:financial_transaction)
    transaction_ids = transactions.map(&:id)
    return {} if transaction_ids.empty?

    installment_group_ids = transactions.filter_map(&:installment_group_id).uniq
    sibling_groups = if installment_group_ids.empty?
                       {}
                     else
                       current_user.transactions.active
                                   .where(installment_group_id: installment_group_ids)
                                   .pluck(:id, :installment_group_id)
                                   .group_by(&:last)
                                   .transform_values { |pairs| pairs.map(&:first) }
                     end

    target_ids = transaction_ids + sibling_groups.values.flatten
    candidates = current_user.classification_suggestions
                             .pending
                             .where(financial_transaction_id: target_ids.uniq)
                             .order(created_at: :desc)
                             .to_a

    transactions.to_h do |transaction|
      ids = transaction.installment_group_id.present? ? sibling_groups.fetch(transaction.installment_group_id, [transaction.id]) : [transaction.id]
      [transaction.id, candidates.find { |candidate| ids.include?(candidate.financial_transaction_id) }]
    end
  end

  def classification_status(transaction, pending_suggestion)
    return 'classified' if transaction.category_id.present? && transaction.category&.user_id == transaction.user_id
    return 'suggestion_pending' if pending_suggestion.equal?(UNSET) ? transaction.pending_classification_suggestion.present? : pending_suggestion.present?

    'unclassified'
  end

  def pagination_page
    value = params[:page].to_i
    value.positive? ? value : 1
  end

  def pagination_per_page
    value = params[:per_page].presence&.to_i || 25
    value.positive? ? [value, 100].min : 25
  end

  def pagination_json(total_count)
    { page: pagination_page, per_page: pagination_per_page, total_count: total_count, total_pages: (total_count.to_f / pagination_per_page).ceil }
  end
end
