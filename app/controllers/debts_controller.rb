class DebtsController < ApplicationController
  before_action :set_debt, only: %i[show edit update destroy]
  before_action :set_cards, only: %i[new edit create]

  # GET /debts or /debts.json
  def index
    @debts = Debt.all

    if params[:description].present? || params[:card_id].present? || params[:paid].present? || params[:has_installment].present? || params[:month].present? || params[:year].present? || params[:note].present?
      @total = 0

      if params[:description].present?
        @debts = @debts.where('description LIKE ?', "%#{params[:description]}%")
      end

      if params[:note].present?
        @debts = @debts.where('note LIKE ?', "%#{params[:note]}%")
      end

      if params[:card_id].present?
        @debts    = @debts.where('card_id = ?', "#{params[:card_id]}")
      end

      if params[:paid].present?
        @debts = @debts.where('paid = ?', params[:paid] == 'true' ? true : false)
      end

      if params[:has_installment].present?
        @debts = @debts.where('has_installment = ?', "#{params[:has_installment]}")
      end

      if params[:month].present? && params[:month] != "0"
        ### POSTGRES OU MYSQL
        # @debts = @debts.where('EXTRACT(MONTH FROM billing_statement) = ?', "#{params[:month]}")
        ### SQLITE3
        months = Array(params[:month]).map { |m| m.to_s.rjust(2, '0') }
        @debts = @debts.where("strftime('%m', billing_statement) IN (?)", months)
        if @debts.present? && params[:card_id].present? && params[:month].size <= 1
          @due_date = (Date.new(Date.today.year, Date.today.month, @debts.last.card.due_date) + 1.month)
        end
      end

      if params[:year].present? && params[:year] != "0"
        ### POSTGRES OU MYSQL
        # @debts = @debts.where('EXTRACT(YEAR FROM billing_statement) = ?', "#{params[:year]}")
        ### SQLITE3
        @debts = @debts.where("strftime('%Y', billing_statement) = ?", "#{params[:year].to_s}")
        if @debts.present? && params[:card_id].present? && params[:month].size <= 1
          @due_date = (Date.new(Date.today.year, Date.today.month, @debts.last.card.due_date) + 1.month) if params[:card_id].present? && params[:month].size <= 1
        end
      end

      @debts.each{|debt| @total += debt.value}
      @debts = @debts.order(paid: :asc, transaction_date: :desc, value: :desc).page(params[:page]).per(99)
    else
      @debts = @debts.order(created_at: :desc).page(params[:page]).per(10)
    end

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

    @debt.value = params[:debt][:value].gsub('.', '').gsub(',', '.')

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
    params[:debt][:value] = params[:debt][:value].gsub('.', '').gsub(',', '.')

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
    # @debt.destroy

    respond_to do |format|
      format.html { redirect_to debts_url, notice: "Debt was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def pay_all
    if params[:card_id].present? && params[:month].present? && params[:year].present?
      months = Array(params[:month]).map { |m| m.to_s.rjust(2, '0') }
      all_debts = Debt.where(card_id: params[:card_id].to_i).where("strftime('%m', billing_statement) IN (?)", months).where("strftime('%Y', billing_statement) = ?", "#{params[:year].to_s}")
      
      if all_debts.present?
        paids = all_debts.update_all(paid: true)

        respond_to do |format|
          if paids.size > 0
            format.html { redirect_to debts_path, notice: "Dívidas atualizadas com sucesso." }
            format.json { render :show, status: :created, location: @debt }
          else
            format.html { render :index, status: :unprocessable_entity }
            format.json { render json: @debt.errors, status: :unprocessable_entity }
          end
        end
      else
        flash[:notice] = "Nenhuma dívida encontrada com esses parâmetros"
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_debt
      @debt = Debt.find(params[:id])
    end

    def set_cards
      @cards = Card.ordenados
    end

    # Only allow a list of trusted parameters through.
    def debt_params
      params.require(:debt).permit(:description, :value, :transaction_date, :billing_statement, :paid, :has_installment, :current_installment, :final_installment, :responsible, :card_id, :note, :category_id)
    end
end
