require 'rails_helper'

RSpec.describe DataEnvironments::HealthCheck, type: :service do
  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:migration_paths) { [Rails.root.join('db/migrate').to_s] }
  let(:required_versions) do
    ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration)
                                  .migrations.map(&:version).sort
  end

  before do
    allow(ApplicationRecord).to receive(:connected_to).and_yield
    allow(ApplicationRecord).to receive(:connection).and_return(connection)
    allow(connection).to receive(:select_value).with('SELECT 1').and_return(1)
    allow(connection).to receive(:migrations_paths).and_return(migration_paths)
    allow(connection).to receive(:quote_table_name)
      .with(ActiveRecord::SchemaMigration.table_name)
      .and_return('"schema_migrations"')
  end

  it 'requires the applied migration versions to exactly match the code' do
    allow(connection).to receive(:select_values).with('SELECT version FROM "schema_migrations"')
      .and_return(required_versions.map(&:to_s))

    result = described_class.call(environment: 'supabase')

    expect(result.connection_available).to be(true)
    expect(result.schema_compatible).to be(true)
    expect(ApplicationRecord).to have_received(:connected_to).with(role: :writing, shard: :supabase)
  end

  it 'rejects the exact missing transaction payments migration from the destination connection' do
    applied_versions = required_versions - [20_260_907_120_000]
    allow(connection).to receive(:select_values).with('SELECT version FROM "schema_migrations"')
      .and_return(applied_versions.map(&:to_s))

    result = described_class.call(environment: 'supabase')

    expect(result.connection_available).to be(true)
    expect(result.schema_compatible).to be(false)
    expect(result.required_versions).to include(20_260_907_120_000)
    expect(result.applied_versions).not_to include(20_260_907_120_000)
  end

  it 'rejects a migration version applied in the database but absent from the code' do
    allow(connection).to receive(:select_values).with('SELECT version FROM "schema_migrations"')
      .and_return((required_versions + [99_999_999_999_999]).map(&:to_s))

    result = described_class.call(environment: 'supabase')

    expect(result.connection_available).to be(true)
    expect(result.schema_compatible).to be(false)
  end

  it 'returns a safe unavailable result for a connection error' do
    allow(ApplicationRecord).to receive(:connected_to).and_raise(ActiveRecord::ConnectionNotEstablished)

    result = described_class.call(environment: 'supabase')

    expect(result.connection_available).to be(false)
    expect(result.schema_compatible).to be(false)
  end
end
