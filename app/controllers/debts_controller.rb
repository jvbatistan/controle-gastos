class DebtsController < ApplicationController
  before_action :set_debt, only: %i[ show edit update destroy ]
  before_action :set_cards, only: %i[ new edit create ]

  # GET /debts or /debts.json
  def index
    @debts = Debt.all

    if params[:search].present?
      @total = 0

      if params[:search][:description].present?
        @debts = @debts.where('description LIKE ?', "%#{params[:search][:description]}%")
      end

      if params[:search][:card_id].present?
        @debts = @debts.where('card_id = ?', "#{params[:search][:card_id]}")
      end

      if params[:search][:has_installment].present?
        @debts = @debts.where('has_installment = ?', "#{params[:search][:has_installment]}")
      end

      @debts.each{|debt| @total += debt.value}
    end

    @debts = @debts.order(created_at: :desc).page(params[:page]).per(10)
  end

  # GET /debts/1 or /debts/1.json
  def show
  end

  # GET /debts/new
  def new
    @debt = Debt.new
  end

  # GET /debts/1/edit
  def edit
  end

  # POST /debts or /debts.json
  def create
    @debt = Debt.new(debt_params)

    respond_to do |format|
      if @debt.save
        format.html { redirect_to debts_path, notice: "Dívida cadastrada com sucesso." }
        format.json { render :show, status: :created, location: @debt }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @debt.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /debts/1 or /debts/1.json
  def update
    respond_to do |format|
      if @debt.update(debt_params)
        format.html { redirect_to debt_url(@debt), notice: "Debt was successfully updated." }
        format.json { render :show, status: :ok, location: @debt }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @debt.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /debts/1 or /debts/1.json
  def destroy
    @debt.destroy

    respond_to do |format|
      format.html { redirect_to debts_url, notice: "Debt was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_debt
      @debt = Debt.find(params[:id])
    end

    def set_cards
      @cards = Card.all.order(:name)
    end

    # Only allow a list of trusted parameters through.
    def debt_params
      params.require(:debt).permit(:description, :value, :transaction_date, :billing_statement, :paid, :has_installment, :current_installment, :final_installment, :responsible, :card_id)
    end
end
