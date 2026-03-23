class Api::CategoriesController < Api::BaseController
  before_action :authenticate_user!
  before_action :set_category, only: [:update, :destroy]

  def index
    categories = current_user.categories.order(:name)

    render json: categories.map { |category| category_json(category) }
  end

  def create
    category = current_user.categories.new(category_params)

    if category.save
      render json: category_json(category), status: :created
    else
      render json: { error: category.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      render json: category_json(@category), status: :ok
    else
      render json: { error: @category.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.in_use?
      render json: { error: 'Categoria em uso e não pode ser removida' }, status: :unprocessable_entity
      return
    end

    if @category.destroy
      head :no_content
    else
      render json: { error: @category.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ActiveRecord::InvalidForeignKey
    render json: { error: 'Categoria em uso e não pode ser removida' }, status: :unprocessable_entity
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :icon)
  end

  def category_json(category)
    {
      id: category.id,
      name: category.name,
      icon: category.icon
    }
  end
end
