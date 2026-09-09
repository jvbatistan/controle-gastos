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
      connection_available = false

      ApplicationRecord.connected_to(role: :writing, shard: environment.to_sym) do
        connection = ApplicationRecord.connection
        connection.select_value('SELECT 1')
        connection_available = true

        required_versions = expected_migration_versions(connection)
        applied_versions = applied_migration_versions(connection)

        Result.new(
          connection_available: true,
          schema_compatible: required_versions == applied_versions,
          required_versions: required_versions,
          applied_versions: applied_versions
        )
      end
    rescue ActiveRecord::ConnectionNotEstablished,
           ActiveRecord::NoDatabaseError
      Result.new(
        connection_available: false,
        schema_compatible: false,
        required_versions: [],
        applied_versions: []
      )
    rescue ActiveRecord::StatementInvalid
      Result.new(
        connection_available: connection_available,
        schema_compatible: false,
        required_versions: [],
        applied_versions: []
      )
    end

    private

    attr_reader :environment

    def expected_migration_versions(connection)
      ActiveRecord::MigrationContext.new(
        connection.migrations_paths,
        ActiveRecord::SchemaMigration
      ).migrations.map(&:version).sort
    end

    def applied_migration_versions(connection)
      schema_migrations = connection.quote_table_name(ActiveRecord::SchemaMigration.table_name)

      connection.select_values("SELECT version FROM #{schema_migrations}").map(&:to_i).sort
    end
  end
end
