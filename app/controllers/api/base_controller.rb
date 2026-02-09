class Api::BaseController < ActionController::Base
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
end
