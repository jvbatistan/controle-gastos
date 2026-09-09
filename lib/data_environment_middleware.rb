class DataEnvironmentMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    environment = DataEnvironments.normalize(request.session[DataEnvironments::SESSION_KEY])

    request.session[DataEnvironments::SESSION_KEY] = environment
    env[DataEnvironments::REQUEST_ENV_KEY] = environment

    ApplicationRecord.connected_to(role: :writing, shard: environment.to_sym) do
      @app.call(env)
    end
  end
end
