class TotalsController < ApplicationController
  before_action :set_all_cards, only: %i[ index ]

  def index
    @months = I18n.t("date.abbr_month_names")
    
    if params[:month].present?
      @month = params[:month].to_i
    end
  end

   def dashboard
    @month = (params[:month] || Date.today.month).to_i
    @year  = (params[:year] || Date.today.year).to_i

    # Usa Date para normalizar o mês/ano (corrige automaticamente meses > 12 ou < 1)
    @current_date = Date.new(@year, @month, 1)

    @cards = Card.with_totals(@month, @year)
    @total_sum = Card.total_sum_for(@month, @year)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_all_cards
      @cards = Card.ordenados
    end
end
