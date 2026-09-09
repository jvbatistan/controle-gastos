require 'rails_helper'
require 'timeout'

RSpec.describe DataEnvironmentMiddleware do
  def rack_env(session_value = :missing)
    session = {}
    session[DataEnvironments::SESSION_KEY] = session_value unless session_value == :missing

    Rack::MockRequest.env_for(
      '/api/probe',
      'rack.session' => session,
      'rack.session.options' => {}
    )
  end

  it 'uses local when the session has no environment' do
    observed = nil
    middleware = described_class.new(lambda do |env|
      observed = [env[DataEnvironments::REQUEST_ENV_KEY], ApplicationRecord.current_shard]
      [200, {}, []]
    end)

    middleware.call(rack_env)

    expect(observed).to eq(['local', :local])
  end

  it 'normalizes an invalid session environment to local' do
    env = rack_env('production')
    observed = nil
    middleware = described_class.new(lambda do |request_env|
      observed = [request_env[DataEnvironments::REQUEST_ENV_KEY], ApplicationRecord.current_shard]
      [200, {}, []]
    end)

    middleware.call(env)

    expect(observed).to eq(['local', :local])
    expect(env['rack.session'][DataEnvironments::SESSION_KEY]).to eq('local')
  end

  it 'restores the previous shard after an exception' do
    middleware = described_class.new(->(_env) { raise 'boom' })

    expect { middleware.call(rack_env('supabase')) }.to raise_error('boom')
    expect(ApplicationRecord.current_shard).to eq(:local)
  end

  it 'keeps simultaneous sessions on different pools while their queries overlap' do
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    middleware = described_class.new(lambda do |env|
      ApplicationRecord.connection_pool.with_connection do |connection|
        ready << true
        release.pop
        connection.select_value('SELECT 1')
        results << [
          env[DataEnvironments::REQUEST_ENV_KEY],
          ApplicationRecord.current_shard,
          connection.pool.db_config.name
        ]
      end
      [200, {}, []]
    end)

    workers = %w[local supabase].map do |environment|
      Thread.new { middleware.call(rack_env(environment)) }
    end

    Timeout.timeout(5) { 2.times { ready.pop } }
    2.times { release << true }
    workers.each(&:join)

    expect(2.times.map { results.pop }).to contain_exactly(
      ['local', :local, 'local'],
      ['supabase', :supabase, 'supabase']
    )
  end
end
