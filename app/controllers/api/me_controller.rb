class Api::MeController < Api::BaseController
  before_action :authenticate_user!

  def show
    render json: {
      id: current_user.id,
      email: current_user.email
    }
  end
end
