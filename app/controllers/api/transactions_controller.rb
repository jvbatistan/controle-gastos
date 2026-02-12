class Api::TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = current_user.transactions.includes(:category, :card).order(date: :desc, created_at: :desc)

    if params[:q].present?
      q = params[:q].to_s.strip
      scope = scope.where("LOWER(description) LIKE ?", "%#{q.downcase}%")
    end

    if params[:category_id].present? && params[:category_id] != "all"
      scope = scope.where(category_id: params[:category_id])
    end

    # 3) Pago / Em aberto
    if params[:paid].present? && params[:paid] != "all"
      paid_value = params[:paid].to_s == "1"
      scope = scope.where(paid: paid_value)
    end

    # 4) Período
    case params[:period]
    when "today"
      scope = scope.where(date: Date.current)
    when "week"
      scope = scope.where(date: 6.days.ago.to_date..Date.current)
    when "month"
      scope = scope.where(date: Date.current.beginning_of_month..Date.current.end_of_month)
    when "last-month"
      last = Date.current.last_month
      scope = scope.where(date: last.beginning_of_month..last.end_of_month)
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
end
