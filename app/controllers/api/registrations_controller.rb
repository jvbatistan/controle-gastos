class Api::RegistrationsController < Api::BaseController
  def create
    user = User.new(sign_up_params)

    if user.save
      sign_in(user)
      render json: user_json(user), status: :created
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
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
