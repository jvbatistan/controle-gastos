require 'rails_helper'

RSpec.describe DataEnvironments::HealthCheck, type: :service do
  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:migration_context) { instance_double(ActiveRecord::MigrationContext) }

  before do
    allow(ApplicationRecord).to receive(:connected_to).and_yield
    allow(ApplicationRecord).to receive(:connection).and_return(connection)
    allow(connection).to receive(:select_value).with('SELECT 1').and_return(1)
    allow(connection).to receive(:migration_context).and_return(migration_context)
  end

  it 'requires the applied migration versions to exactly match the code' do
    migrations = [instance_double(ActiveRecord::MigrationProxy, version: 1), instance_double(ActiveRecord::MigrationProxy, version: 2)]
    allow(migration_context).to receive(:migrations).and_return(migrations)
    allow(migration_context).to receive(:get_all_versions).and_return([2, 1])

    result = described_class.call(environment: 'supabase')

    expect(result.connection_available).to be(true)
    expect(result.schema_compatible).to be(true)
    expect(ApplicationRecord).to have_received(:connected_to).with(role: :writing, shard: :supabase)
  end

  it 'rejects missing or unexpected migration versions' do
    migrations = [instance_double(ActiveRecord::MigrationProxy, version: 1), instance_double(ActiveRecord::MigrationProxy, version: 2)]
    allow(migration_context).to receive(:migrations).and_return(migrations)
    allow(migration_context).to receive(:get_all_versions).and_return([1, 3])

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
