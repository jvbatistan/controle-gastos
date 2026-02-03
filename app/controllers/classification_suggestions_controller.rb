class ClassificationSuggestionsController < ApplicationController
  def index
    @suggestions = ClassificationSuggestion
      .pending
      .includes(:financial_transaction, :suggested_category)
      .order(created_at: :desc)
  end

  def accept
    suggestion = ClassificationSuggestion.find(params[:id])
    tx = suggestion.financial_transaction
    category_id = suggestion.suggested_category_id

    Transaction.transaction do
      tx.update!(category_id: category_id)
      suggestion.update!(accepted_at: Time.current)

      propagate_to_installment_group!(tx, category_id, mark_as: :accepted)

      Merchants::UpsertAliasService.new(description: tx.description, category_id: category_id, confidence: suggestion.confidence, source: :user_override).call
    end

    redirect_to classification_suggestions_path, notice: "✅ Sugestão aplicada!"
  end

  def reject
    suggestion = ClassificationSuggestion.find(params[:id])
    tx = suggestion.financial_transaction

    Transaction.transaction do
      suggestion.update!(rejected_at: Time.current)

      propagate_to_installment_group!(tx, tx.category_id, mark_as: :rejected)
    end

    redirect_to classification_suggestions_path, notice: "🚫 Sugestão recusada."
  end

  def correct
    suggestion = ClassificationSuggestion.find(params[:id])
    category_id = params.dig(:classification_suggestion, :category_id)

    raise ActionController::ParameterMissing, :classification_suggestion if category_id.blank?

    tx = suggestion.financial_transaction

    Transaction.transaction do
      tx.update!(category_id: category_id)
      suggestion.update!(rejected_at: Time.current)

      propagate_to_installment_group!(tx, category_id, mark_as: :rejected)

      Merchants::UpsertAliasService.new(description: tx.description, category_id: category_id, confidence: 1.0, source: :user_override).call
    end

    redirect_to classification_suggestions_path, notice: "✅ Correção aplicada e aprendizado salvo!"
  end

  private

  def propagate_to_installment_group!(transaction, category_id, mark_as:)
    gid = transaction.installment_group_id
    return 0 if gid.blank?

    updated = Transactions::ApplyCategoryToInstallmentGroupService.new(transaction: transaction, category_id: category_id).call

    tx_ids = Transaction.where(installment_group_id: gid).pluck(:id)

    scope = ClassificationSuggestion.where(financial_transaction_id: tx_ids, accepted_at: nil, rejected_at: nil)

    now = Time.current

    if mark_as == :accepted
      scope.update_all(accepted_at: now, updated_at: now)
    else
      scope.update_all(rejected_at: now, updated_at: now)
    end

    updated
  end
end
