class Api::AccountsController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_account, only: %i[show update destroy restore statement export_csv]

  def index
    accounts = if ActiveRecord::Type::Boolean.new.cast(params[:archived])
                 current_user.accounts.archived.ordered
               else
                 current_user.accounts.active.ordered
               end
    balances = Accounts::BalanceCalculator.for(accounts)

    render json: accounts.map { |account| account_json(account, current_balance: balances[account.id]) }
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

  def statement
    result = Accounts::StatementBuilder.call(account: @account, params: statement_params)

    render json: {
      account: account_json(@account),
      period: result.period,
      filters: result.filters,
      balances: result.balances,
      summary: result.summary,
      pagination: result.pagination,
      items: result.items.map(&:as_json)
    }, status: :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def export_csv
    result = Accounts::StatementBuilder.call(
      account: @account,
      params: statement_export_params,
      paginate: false
    )
    csv = Accounts::StatementCsvExporter.call(result)

    send_data(
      csv,
      filename: Accounts::StatementCsvExporter.filename(result),
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
    )
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :kind, :initial_balance, :initial_balance_date)
  end

  def statement_params
    params.permit(:start_date, :end_date, :movement_type, :direction, :page, :per_page)
  end

  def statement_export_params
    params.permit(:start_date, :end_date, :movement_type, :direction)
  end

  def account_json(account, current_balance: nil)
    {
      id: account.id,
      name: account.name,
      kind: account.kind,
      initial_balance: account.initial_balance,
      initial_balance_date: account.initial_balance_date,
      current_balance: current_balance || account.current_balance,
      archived_at: account.archived_at,
      created_at: account.created_at,
      updated_at: account.updated_at
    }
  end
end
