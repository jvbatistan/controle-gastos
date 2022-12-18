class TotalsController < ApplicationController
  before_action :set_all_cards, only: %i[ index ]

  def index
    @months = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ']
    
    if params[:month].present?
      @month = params[:month].rjust(2, '0')
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_all_cards
      @cards = Card.order(:name)
    end
end
