require 'rails_helper'

RSpec.describe 'Api::DataEnvironments', type: :request do
  self.use_transactional_tests = false

  let(:password) { 'password123' }
  let(:switch_headers) { { 'X-Finch-Data-Environment-Switch' => 'confirmed' } }

  after do
    (@created_operator_emails || {}).each do |environment, emails|
      ApplicationRecord.connected_to(role: :writing, shard: environment) do
        User.where(email: emails).delete_all
      end
    end
  end

  def create_operator(email, environment: :local)
    @created_operator_emails ||= Hash.new { |hash, key| hash[key] = [] }
    @created_operator_emails[environment] << email

    ApplicationRecord.connected_to(role: :writing, shard: environment) do
      create(:user, email: email, password: password, password_confirmation: password)
    end
  end

  describe 'GET /api/data_environment' do
    it 'defaults to local and exposes only the small UI contract' do
      user = create_operator('homologacao@finch.local')
      sign_in user

      get '/api/data_environment'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(
        'environment' => 'local',
        'connection_status' => 'available',
        'schema_compatible' => true,
        'can_switch_data_environment' => true
      )
      expect(response.body).not_to match(/database_url|host|password|postgresql:\/\//i)
    end

    it 'does not grant switch permission to another user' do
      user = create_operator('another@example.com')
      sign_in user

      get '/api/data_environment'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['can_switch_data_environment']).to be(false)
    end

    it 'requires authentication' do
      get '/api/data_environment'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/data_environment/switch' do
    it 'signs out before resetting the session, never reuses the local login, and selects supabase next' do
      local_user = create_operator('homologacao@finch.local')
      supabase_user = create_operator('joao@controle.local', environment: :supabase)
      switch_events = []
      allow_any_instance_of(Api::DataEnvironmentsController).to receive(:sign_out).and_wrap_original do |method, *args|
        switch_events << [:sign_out, args]
        method.call(*args)
      end
      allow_any_instance_of(Api::DataEnvironmentsController).to receive(:reset_session).and_wrap_original do |method, *args|
        switch_events << [:reset_session, args]
        method.call(*args)
      end
      sign_in local_user

      post '/api/data_environment/switch', params: { environment: 'supabase' }, headers: switch_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(
        'environment' => 'supabase',
        'reauthentication_required' => true
      )
      expect(switch_events).to eq([[:sign_out, [:user]], [:reset_session, []]])

      get '/api/me'
      expect(response).to have_http_status(:unauthorized)

      post '/api/login', params: { email: supabase_user.email, password: password }
      expect(response).to have_http_status(:ok)

      get '/api/data_environment'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(
        'environment' => 'supabase',
        'can_switch_data_environment' => true
      )
    end

    it 'allows the authorized supabase operator to return to local and requires another login' do
      local_user = create_operator('homologacao@finch.local')
      supabase_user = create_operator('joao@controle.local', environment: :supabase)
      sign_in local_user

      post '/api/data_environment/switch', params: { environment: 'supabase' }, headers: switch_headers
      post '/api/login', params: { email: supabase_user.email, password: password }
      post '/api/data_environment/switch', params: { environment: 'local' }, headers: switch_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(
        'environment' => 'local',
        'reauthentication_required' => true
      )

      get '/api/me'
      expect(response).to have_http_status(:unauthorized)

      post '/api/login', params: { email: local_user.email, password: password }
      expect(response).to have_http_status(:ok)

      get '/api/data_environment'
      expect(JSON.parse(response.body)['environment']).to eq('local')
    end

    it 'rejects a user who is not authorized in the current environment' do
      user = create_operator('another@example.com')
      sign_in user

      post '/api/data_environment/switch', params: { environment: 'supabase' }, headers: switch_headers

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to eq('Usuário não autorizado a trocar o ambiente de dados.')

      get '/api/me'
      expect(response).to have_http_status(:ok)
    end

    it 'rejects an invalid environment without changing the session or login' do
      user = create_operator('homologacao@finch.local')
      sign_in user

      post '/api/data_environment/switch', params: { environment: 'production' }, headers: switch_headers

      expect(response).to have_http_status(:unprocessable_entity)

      get '/api/data_environment'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['environment']).to eq('local')
    end

    it 'preserves the current environment and login when the destination connection fails' do
      user = create_operator('homologacao@finch.local')
      sign_in user
      failed_health = DataEnvironments::HealthCheck::Result.new(
        connection_available: false,
        schema_compatible: false,
        required_versions: [],
        applied_versions: []
      )
      allow(DataEnvironments::HealthCheck).to receive(:call).and_call_original
      allow(DataEnvironments::HealthCheck).to receive(:call)
        .with(environment: 'supabase')
        .and_return(failed_health)

      post '/api/data_environment/switch', params: { environment: 'supabase' }, headers: switch_headers

      expect(response).to have_http_status(:service_unavailable)

      get '/api/me'
      expect(response).to have_http_status(:ok)
      get '/api/data_environment'
      expect(JSON.parse(response.body)['environment']).to eq('local')
    end

    it 'preserves the current environment and login when the destination schema is incompatible' do
      user = create_operator('homologacao@finch.local')
      sign_in user
      incompatible_health = DataEnvironments::HealthCheck::Result.new(
        connection_available: true,
        schema_compatible: false,
        required_versions: [1, 2],
        applied_versions: [1]
      )
      allow(DataEnvironments::HealthCheck).to receive(:call).and_call_original
      allow(DataEnvironments::HealthCheck).to receive(:call)
        .with(environment: 'supabase')
        .and_return(incompatible_health)

      post '/api/data_environment/switch', params: { environment: 'supabase' }, headers: switch_headers

      expect(response).to have_http_status(:conflict)

      get '/api/me'
      expect(response).to have_http_status(:ok)
      get '/api/data_environment'
      expect(JSON.parse(response.body)['environment']).to eq('local')
    end

    it 'rejects a browser-form style request without the explicit switch header' do
      user = create_operator('homologacao@finch.local')
      sign_in user

      post '/api/data_environment/switch', params: { environment: 'supabase' }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to eq('Confirmação de troca de ambiente ausente.')

      get '/api/me'
      expect(response).to have_http_status(:ok)
      get '/api/data_environment'
      expect(JSON.parse(response.body)['environment']).to eq('local')
    end
  end
end
