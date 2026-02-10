class Api::CategoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    categories = current_user.categories.order(:name)

    render json: categories.as_json(only: [:id, :name])
  end
end
