module DataEnvironments
  LOCAL = 'local'.freeze
  SUPABASE = 'supabase'.freeze
  ALL = [LOCAL, SUPABASE].freeze
  SESSION_KEY = :data_environment
  REQUEST_ENV_KEY = 'finch.data_environment'.freeze

  module_function

  def normalize(value)
    value = value.to_s
    ALL.include?(value) ? value : LOCAL
  end

  def current(request)
    normalize(request.env[REQUEST_ENV_KEY])
  end

  def real_data?(request)
    current(request) == SUPABASE
  end

  def opposite(environment)
    normalize(environment) == LOCAL ? SUPABASE : LOCAL
  end
end
