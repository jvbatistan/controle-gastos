class TotalsController < ApplicationController
  before_action :set_all_cards, only: %i[ index ]

  def index
    @months = I18n.t("date.abbr_month_names")
    
    if params[:month].present?
      @month = params[:month].to_i
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_all_cards
      @cards = Card.order(:name)
    end
end
