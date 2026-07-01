class Api::AccountsController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_account, only: %i[show update destroy restore]

  def index
    accounts = if ActiveRecord::Type::Boolean.new.cast(params[:archived])
                 current_user.accounts.archived.ordered
               else
                 current_user.accounts.active.ordered
               end

    render json: accounts.map { |account| account_json(account) }
  end

  def show
    render json: account_json(@account)
  end

  def create
    account = current_user.accounts.new(account_params)

    if account.save
      render json: account_json(account), status: :created
    else
      render json: { error: account.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    if @account.update(account_params)
      render json: account_json(@account), status: :ok
    else
      render json: { error: @account.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @account.archive!

    render json: account_json(@account.reload), status: :ok
  end

  def restore
    @account.restore!

    render json: account_json(@account.reload), status: :ok
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :kind, :initial_balance, :initial_balance_date)
  end

  def account_json(account)
    {
      id: account.id,
      name: account.name,
      kind: account.kind,
      initial_balance: account.initial_balance,
      initial_balance_date: account.initial_balance_date,
      current_balance: account.current_balance,
      archived_at: account.archived_at,
      created_at: account.created_at,
      updated_at: account.updated_at
    }
  end
end
