class Api::MeController < Api::BaseController
  before_action :authenticate_user!

  def show
    render json: user_json(current_user)
  end

  def update
    if current_user.update(profile_params)
      render json: user_json(current_user), status: :ok
    else
      render json: { error: current_user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email)
  end

  def user_json(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      active: user.active
    }
  end
end
