class Api::AccountTransfersController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_account_transfer, only: %i[show reverse]

  def index
    transfers = current_user.account_transfers
                            .includes(:from_account, :to_account)
                            .ordered
    transfers = transfers.where(status: status_filter) if status_filter.present?
    transfers = filter_by_account(transfers)

    render json: transfers.map { |transfer| account_transfer_json(transfer) }, status: :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
    render json: account_transfer_json(@account_transfer), status: :ok
  end

  def create
    transfer = current_user.account_transfers.new(account_transfer_params)
    transfer.from_account = active_account_param(:from_account_id)
    transfer.to_account = active_account_param(:to_account_id)
    transfer.status = :completed

    if transfer.save
      render json: account_transfer_json(transfer), status: :created
    else
      render json: { error: transfer.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reverse
    @account_transfer.with_lock do
      @account_transfer.reversed! if @account_transfer.completed?
    end

    render json: account_transfer_json(@account_transfer.reload), status: :ok
  end

  private

  def set_account_transfer
    @account_transfer = current_user.account_transfers.find(params[:id])
  end

  def account_transfer_params
    params.require(:account_transfer).permit(:amount, :transferred_on, :description, :note)
  end

  def active_account_param(param_name)
    account_id = params.dig(:account_transfer, param_name).presence
    raise ArgumentError, required_account_message(param_name) if account_id.blank?

    current_user.accounts.active.find(account_id)
  end

  def required_account_message(param_name)
    return "Conta de origem é obrigatória." if param_name == :from_account_id

    "Conta de destino é obrigatória."
  end

  def status_filter
    return nil if params[:status].blank?
    return params[:status] if AccountTransfer.statuses.key?(params[:status])

    raise ArgumentError, "Status inválido."
  end

  def filter_by_account(transfers)
    return transfers if params[:account_id].blank?

    account = current_user.accounts.find_by(id: params[:account_id])
    return transfers.none if account.blank?

    transfers.where(from_account_id: account.id).or(transfers.where(to_account_id: account.id))
  end

  def account_transfer_json(transfer)
    {
      id: transfer.id,
      from_account: account_json(transfer.from_account),
      to_account: account_json(transfer.to_account),
      amount: transfer.amount,
      transferred_on: transfer.transferred_on,
      description: transfer.description,
      note: transfer.note,
      status: transfer.status,
      created_at: transfer.created_at,
      updated_at: transfer.updated_at
    }
  end

  def account_json(account)
    {
      id: account.id,
      name: account.name
    }
  end
end
