class TotalsController < ApplicationController
  before_action :set_all_cards, only: %i[ index ]

  def index
    @months = I18n.t("date.abbr_month_names")

    @month = (params[:month] || Date.today.month).to_i
    @year  = (params[:year] || Date.today.year).to_i
    
    @current_date = Date.new(@year, @month, 1)

    @cards = current_user.cards.with_totals(@month, @year)
    @total_sum = current_user.cards.total_sum_for(@month, @year)

    start_date = Date.new(@year.to_i, @month.to_i, 1)
    end_date   = start_date.end_of_month

    @other_transactions = current_user.transactions
      .where(card_id: nil)
      .where(source: [:cash, :bank]) # avulsas
      .where(date: start_date..end_date)
      .order(date: :desc, value: :desc, description: :asc)

    @other_total = @other_transactions.where(paid: false).sum(:value)
  end

  def dashboard
    @month = (params[:month] || Date.today.month).to_i
    @year  = (params[:year] || Date.today.year).to_i

    # Usa Date para normalizar o mês/ano (corrige automaticamente meses > 12 ou < 1)
    @current_date = Date.new(@year, @month, 1)

    @cards = current_user.cards.with_totals(@month, @year)
    # @total_sum = Card.total_sum_for(@month, @year)

    @statements_by_card_id = {}

    @total_sum = 0.to_d

    @cards.each do |card|
      st = card.sync_statement!(@month, @year)
      @statements_by_card_id[card.id] = st

      @total_sum += st.remaining_amount
    end
    
    start_date = @current_date
    end_date   = @current_date.end_of_month

    @other_transactions = current_user.transactions
      .where(card_id: nil)
      .where(source: [:cash, :bank])
      .where(date: start_date..end_date)
      .order(date: :desc, value: :desc, description: :asc)

    @other_total = @other_transactions.where(paid: false).sum(:value)

    # soma no total geral
    @total_sum += @other_total
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_all_cards
      @cards = current_user.cards.ordenados
    end
end
