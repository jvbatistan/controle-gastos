require 'rails_helper'
require 'securerandom'

RSpec.describe 'ApplicationRecord shard isolation', type: :model do
  self.use_transactional_tests = false

  def with_temporary_probe(environment, table_name, value)
    ApplicationRecord.connected_to(role: :writing, shard: environment) do
      ApplicationRecord.connection_pool.with_connection do |connection|
        quoted_table = connection.quote_table_name(table_name)
        connection.execute("CREATE TEMPORARY TABLE #{quoted_table} (value varchar(32) NOT NULL)")
        connection.execute(
          "INSERT INTO #{quoted_table} (value) VALUES (#{connection.quote(value)})"
        )
        yield connection, quoted_table
      ensure
        connection.execute("DROP TABLE IF EXISTS #{quoted_table}") if connection && quoted_table
      end
    end
  end

  it 'keeps local temporary writes invisible to the supabase pool' do
    table_name = "probe_local_#{SecureRandom.hex(6)}"

    with_temporary_probe(:local, table_name, 'local-only') do |local_connection, quoted_table|
      ApplicationRecord.connected_to(role: :writing, shard: :supabase) do
        expect {
          ApplicationRecord.connection.select_value("SELECT value FROM #{quoted_table}")
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      expect(local_connection.select_value("SELECT value FROM #{quoted_table}")).to eq('local-only')
    end
  end

  it 'keeps supabase temporary writes invisible to the local pool' do
    table_name = "probe_supabase_#{SecureRandom.hex(6)}"

    with_temporary_probe(:supabase, table_name, 'supabase-only') do |supabase_connection, quoted_table|
      ApplicationRecord.connected_to(role: :writing, shard: :local) do
        expect {
          ApplicationRecord.connection.select_value("SELECT value FROM #{quoted_table}")
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      expect(supabase_connection.select_value("SELECT value FROM #{quoted_table}")).to eq('supabase-only')
    end
  end
end
