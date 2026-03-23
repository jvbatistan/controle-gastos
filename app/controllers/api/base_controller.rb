class Api::BaseController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  include ActionController::Cookies

  skip_before_action :verify_authenticity_token
  respond_to :json

  private

  def authenticate_user!
    if user_signed_in?
      super
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def render_not_found
    render json: { error: "Not found" }, status: :not_found
  end
end
