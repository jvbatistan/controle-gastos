class Api::DataEnvironmentsController < Api::BaseController
  before_action :authenticate_user!
  before_action :require_switch_confirmation!, only: :switch

  def show
    health = DataEnvironments::HealthCheck.call(environment: current_data_environment)

    render json: environment_json(health)
  end

  def switch
    target_environment = params[:environment].to_s

    unless DataEnvironments::ALL.include?(target_environment)
      return render json: { error: 'Ambiente de dados inválido.' }, status: :unprocessable_entity
    end

    unless target_environment == DataEnvironments.opposite(current_data_environment)
      return render json: { error: 'O ambiente solicitado já está ativo.' }, status: :unprocessable_entity
    end

    unless DataEnvironments::Authorization.allowed?(user: current_user, environment: current_data_environment)
      return render json: { error: 'Usuário não autorizado a trocar o ambiente de dados.' }, status: :forbidden
    end

    health = DataEnvironments::HealthCheck.call(environment: target_environment)

    unless health.connection_available
      return render json: { error: 'O ambiente de destino está indisponível.' }, status: :service_unavailable
    end

    unless health.schema_compatible
      return render json: { error: 'O ambiente de destino possui schema incompatível.' }, status: :conflict
    end

    sign_out(:user)
    reset_session
    session[DataEnvironments::SESSION_KEY] = target_environment

    render json: {
      environment: target_environment,
      reauthentication_required: true
    }
  end

  private

  def require_switch_confirmation!
    return if request.headers['X-Finch-Data-Environment-Switch'] == 'confirmed'

    render json: { error: 'Confirmação de troca de ambiente ausente.' }, status: :forbidden
  end

  def environment_json(health)
    {
      environment: current_data_environment,
      connection_status: health.connection_available ? 'available' : 'unavailable',
      schema_compatible: health.schema_compatible,
      can_switch_data_environment: DataEnvironments::Authorization.allowed?(
        user: current_user,
        environment: current_data_environment
      )
    }
  end
end
