class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[show edit update destroy]
  before_action :set_cards, only: %i[index new edit create]

  # GET /transactions or /transactions.json
  def index
    @transactions = current_user.transactions.order(date: :desc, id: :desc)

    @month    = params[:month].presence
    @year     = params[:year].presence
    @card_id  = params[:card_id].presence

    if @card_id.present?
      if @card_id == "none"
        @transactions = @transactions.where(card_id: nil)
      else
        if current_user.cards.exists?(@card_id)
          @transactions = @transactions.where(card_id: @card_id)
        else
          @transactions = @transactions.none
        end
      end
    end

    if @month.present? && @year.present?
      month_i = @month.to_i
      year_i  = @year.to_i

      start_date = Date.new(year_i, month_i, 1)
      end_date   = start_date.end_of_month

      if @card_id.blank?
        @transactions = @transactions.where("(card_id IS NOT NULL AND billing_statement >= ? AND billing_statement <= ?) OR (card_id IS NULL AND date >= ? AND date <= ?)", start_date, end_date, start_date, end_date)
      else
        if @card_id == "none"
          @transactions = @transactions.where(date: start_date..end_date)
        else
          @transactions = @transactions.where(billing_statement: start_date..end_date)
        end
      end
    end

    @total_sum = @transactions.sum(:value) if @month.present? && @year.present?
  end

  # GET /transactions/new
  def new
    @transaction = current_user.transactions.new(kind: :expense, date: Date.today, source: :card)
  end

  # POST /transactions or /transactions.json
  def create
    @transaction = current_user.transactions.new(transaction_params)

    unless valid_card_and_category_owner?(@transaction)
      flash.now[:alert] = "Cartão e/ou categoria inválidos."
      return render :new
    end

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

  # GET /transactions/1/edit
  def edit
  end

  # PATCH/PUT /transactions/1 or /transactions/1.json
  def update
    @transaction.assign_attributes(transaction_params_for_update)

    unless valid_card_and_category_owner?(@transaction)
      flash.now[:alert] = "Cartão e/ou categoria inválidos."
      return render :edit
    end

    if @transaction.save
      redirect_to transactions_path, notice: "✅ Transação atualizada!"
    else
      render :edit
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :edit
  end

  # DELETE /transactions/1 or /transactions/1.json
  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: "Transação excluída com sucesso."
  end

  # def pay_all
  #   if params[:card_id].present? && params[:month].present? && params[:year].present?
  #     months = Array(params[:month]).map { |m| m.to_s.rjust(2, '0') }
  #     all_transactions = Transaction.where(card_id: params[:card_id].to_i).where("to_char(billing_statement, 'MM') IN (?)", months).where("to_char(billing_statement, 'YYYY') = ?", "#{params[:year].to_s}")
      
  #     if all_transactions.present?
  #       paids = all_transactions.update_all(paid: true)

  #       respond_to do |format|
  #         if paids > 0
  #           format.html { redirect_to transactions_path, notice: "Dívidas atualizadas com sucesso." }
  #           format.json { render :show, status: :created, location: @transaction }
  #         else
  #           format.html { render :index, status: :unprocessable_entity }
  #           format.json { render json: @transaction.errors, status: :unprocessable_entity }
  #         end
  #       end
  #     else
  #       flash[:notice] = "Nenhuma dívida encontrada com esses parâmetros"
  #     end
  #   end
  # end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_transaction
      @transaction = current_user.transactions.find(params[:id])
    end

    def set_cards
      @cards = current_user.cards.ordenados
    end

    def valid_card_and_category_owner?(transaction)
      if transaction.card_id.present? && !current_user.cards.exists?(transaction.card_id)
        transaction.errors.add(:card, "inválido")
        return false
      end

      if transaction.category_id.present? && !current_user.categories.exists?(transaction.category_id)
        transaction.errors.add(:category, "inválido")
        return false
      end

      true
    end

    def transaction_params
      params.require(:transaction).permit(
        :description, :value, :date, :kind, :source, :paid,
        :note, :responsible, :card_id, :category_id, :billing_statement,
        :installment_number, :installments_count
      )
    end

    def transaction_params_for_update
      params.require(:transaction).permit(
        :description, :value, :date, :kind, :source, :paid,
        :note, :responsible, :card_id, :category_id, :billing_statement
      )
    end
end
