module DataEnvironments
  class HealthCheck
    Result = Struct.new(
      :connection_available,
      :schema_compatible,
      :required_versions,
      :applied_versions,
      keyword_init: true
    )

    def self.call(environment:)
      new(environment: environment).call
    end

    def initialize(environment:)
      @environment = DataEnvironments.normalize(environment)
    end

    def call
      ApplicationRecord.connected_to(role: :writing, shard: environment.to_sym) do
        connection = ApplicationRecord.connection
        connection.select_value('SELECT 1')

        migration_context = connection.migration_context
        required_versions = migration_context.migrations.map(&:version).sort
        applied_versions = migration_context.get_all_versions.sort

        Result.new(
          connection_available: true,
          schema_compatible: required_versions == applied_versions,
          required_versions: required_versions,
          applied_versions: applied_versions
        )
      end
    rescue ActiveRecord::ConnectionNotEstablished,
           ActiveRecord::NoDatabaseError,
           ActiveRecord::StatementInvalid
      Result.new(
        connection_available: false,
        schema_compatible: false,
        required_versions: [],
        applied_versions: []
      )
    end

    private

    attr_reader :environment
  end
end
