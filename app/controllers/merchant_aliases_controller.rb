class MerchantAliasesController < ApplicationController
  before_action :set_merchant_alias, only: %i[edit update destroy]
  before_action :set_categories, only: %i[new edit create update]

  def index
    @merchant_aliases = current_user.merchant_aliases.includes(:category).order(:normalized_merchant)
  end

  def new
    @merchant_alias = current_user.merchant_aliases.new(source: :user_override, confidence: 1.0)
  end

  def create
    @merchant_alias = current_user.merchant_aliases.new(merchant_alias_params)

    unless current_user.categories.exists?(@merchant_alias.category_id)
      @merchant_alias.errors.add(:category, "inválida")
      return render :new
    end

    if @merchant_alias.save
      redirect_to merchant_aliases_path, notice: "✅ Alias cadastrado!"
    else
      render :new
    end
  end

  def edit; end

  def update
    @merchant_alias.assign_attributes(merchant_alias_params)

    unless current_user.categories.exists?(@merchant_alias.category_id)
      @merchant_alias.errors.add(:category, "inválida")
      return render :edit
    end

    if @merchant_alias.save
      redirect_to merchant_aliases_path, notice: "✅ Alias atualizado!"
    else
      render :edit
    end
  end

  def destroy
    @merchant_alias.destroy
    redirect_to merchant_aliases_path, notice: "Alias removido."
  end

  private

  def set_merchant_alias
    @merchant_alias = current_user.merchant_aliases.find(params[:id])
  end

  def set_categories
    @categories = current_user.categories.order(:name)
  end

  def merchant_alias_params
    params.require(:merchant_alias).permit(:normalized_merchant, :category_id, :confidence, :source)
  end
end
