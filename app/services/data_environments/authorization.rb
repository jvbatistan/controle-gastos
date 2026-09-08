module DataEnvironments
  class Authorization
    DEFAULT_LOCAL_OPERATOR_EMAIL = 'homologacao@finch.local'.freeze
    DEFAULT_SUPABASE_OPERATOR_EMAIL = 'joao@controle.local'.freeze

    def self.allowed?(user:, environment:)
      return false unless user

      expected_email = case DataEnvironments.normalize(environment)
                       when DataEnvironments::LOCAL
                         ENV.fetch('DATA_ENVIRONMENT_LOCAL_OPERATOR_EMAIL', DEFAULT_LOCAL_OPERATOR_EMAIL)
                       when DataEnvironments::SUPABASE
                         ENV.fetch('DATA_ENVIRONMENT_SUPABASE_OPERATOR_EMAIL', DEFAULT_SUPABASE_OPERATOR_EMAIL)
                       end

      user.email.to_s.casecmp?(expected_email.to_s.strip)
    end
  end
end
