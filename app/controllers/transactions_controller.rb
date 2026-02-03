class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[show edit update destroy]
  before_action :set_cards, only: %i[new edit create]

  # GET /transactions or /transactions.json
  def index
    @transactions = Transaction.order(date: :desc, created_at: :desc).limit(200)

    # if params[:description].present? || params[:card_id].present? || params[:paid].present? || params[:has_installment].present? || params[:month].present? || params[:year].present? || params[:note].present? || params[:category_id].present? || params[:expense_type].present?
    #   @total = 0

    #   if params[:description].present?
    #     @transactions = @transactions.where('description LIKE ?', "%#{params[:description]}%")
    #   end

    #   if params[:note].present?
    #     @transactions = @transactions.where('note LIKE ?', "%#{params[:note]}%")
    #   end

    #   if params[:card_id].present?
    #     @transactions    = @transactions.where('card_id = ?', "#{params[:card_id]}")
    #   end

    #   if params[:paid].present?
    #     @transactions = @transactions.where('paid = ?', params[:paid] == 'true' ? true : false)
    #   end

    #   if params[:has_installment].present?
    #     @transactions = @transactions.where('has_installment = ?', "#{params[:has_installment]}")
    #   end

    #   if params[:category_id].present?
    #     @transactions = @transactions.where('category_id = ?', "#{params[:category_id]}")
    #   end

    #   if params[:expense_type].present?
    #     @transactions = @transactions.where('expense_type = ?', "#{params[:expense_type]}")
    #   end

    #   if params[:month].present? && params[:month] != "0"
    #     ### POSTGRES OU MYSQL
    #     months = Array(params[:month]).map { |m| m.to_s.rjust(2, '0') }
    #     @transactions = @transactions.where('EXTRACT(MONTH FROM billing_statement) = ?', months)
    #     ### SQLITE3
    #     # @transactions = @transactions.where("strftime('%m', billing_statement) IN (?)", months)
    #     if @transactions.present? && params[:card_id].present? && params[:month].size <= 1
    #       @due_date = (Date.new(Date.today.year, Date.today.month, @transactions.last.card.due_date) + 1.month)
    #     end
    #   end

    #   if params[:year].present? && params[:year] != "0"
    #     ### POSTGRES OU MYSQL
    #     @transactions = @transactions.where('EXTRACT(YEAR FROM billing_statement) = ?', "#{params[:year]}")
    #     ### SQLITE3
    #     # @transactions = @transactions.where("strftime('%Y', billing_statement) = ?", "#{params[:year].to_s}")
    #     if @transactions.present? && params[:card_id].present? && params[:month].size <= 1
    #       @due_date = (Date.new(Date.today.year, Date.today.month, @transactions.last.card.due_date) + 1.month) if params[:card_id].present? && params[:month].size <= 1
    #     end
    #   end

    #   @transactions.each{|transaction| @total += transaction.value}
    #   @transactions = @transactions.order(paid: :asc, transaction_date: :desc, value: :desc).page(params[:page]).per(99)
    # else
    #   @transactions = @transactions.order(created_at: :desc).page(params[:page]).per(10)
    # end
  end

  # GET /transactions/1 or /transactions/1.json
  def show
  end

  # GET /transactions/new
  def new
    @transaction = Transaction.new(kind: :expense, date: Date.today, source: :card)
  end

  # GET /transactions/1/edit
  def edit
  end

  # POST /transactions or /transactions.json
  def create
    @transaction = Transaction.new(transaction_params)

    final   = params[:transaction][:installments_count].to_i
    current = (params[:transaction][:installment_number].presence || 1).to_i

    if final > 1
      Transactions::InstallmentGeneratorService.new(@transaction, current_installment: current, final_installment: final).call

      redirect_to transactions_path, notice: "✅ Parcelamento cadastrado!"
      return
    end
    
    @transaction.installment_number  = nil
    @transaction.installments_count  = nil
    @transaction.installment_group_id = nil
    
    if @transaction.save
      redirect_to transactions_path, notice: "✅ Transação cadastrada!"
    else
      render :new
    end
  rescue ArgumentError => e
    flash.now[:alert] = e.message
    render :new
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new
  end


  # PATCH/PUT /transactions/1 or /transactions/1.json
  def update
    respond_to do |format|
      if @transaction.update(transaction_params)
        format.html { redirect_to transaction_url(@transaction), notice: "Transaction was successfully updated." }
        format.json { render :show, status: :ok, location: @transaction }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @transaction.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /transactions/1 or /transactions/1.json
  def destroy
    @transaction.destroy

    respond_to do |format|
      format.html { redirect_to transactions_url, notice: "Transaction was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def pay_all
    if params[:card_id].present? && params[:month].present? && params[:year].present?
      months = Array(params[:month]).map { |m| m.to_s.rjust(2, '0') }
      all_transactions = Transaction.where(card_id: params[:card_id].to_i).where("to_char(billing_statement, 'MM') IN (?)", months).where("to_char(billing_statement, 'YYYY') = ?", "#{params[:year].to_s}")
      
      if all_transactions.present?
        paids = all_transactions.update_all(paid: true)

        respond_to do |format|
          if paids > 0
            format.html { redirect_to transactions_path, notice: "Dívidas atualizadas com sucesso." }
            format.json { render :show, status: :created, location: @transaction }
          else
            format.html { render :index, status: :unprocessable_entity }
            format.json { render json: @transaction.errors, status: :unprocessable_entity }
          end
        end
      else
        flash[:notice] = "Nenhuma dívida encontrada com esses parâmetros"
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_transaction
      @transaction = Transaction.find(params[:id])
    end

    def set_cards
      @cards = Card.ordenados
    end

    # Only allow a list of trusted parameters through.
    def transaction_params
      params.require(:transaction).permit(
        :description, :value, :date, :kind, :source, :paid, :responsible,
        :card_id, :category_id, :note,
        :installments_count, :installment_number
      )
    end
end
