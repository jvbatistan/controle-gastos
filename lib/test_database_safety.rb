require 'uri'

module TestDatabaseSafety
  class UnsafeDatabaseError < StandardError; end

  DatabaseTarget = Struct.new(:adapter, :host, :port, :database, keyword_init: true)

  TEST_DATABASE_NAME_PATTERN = /(?:\A|[_-])test(?:\z|[_-])/i.freeze
  POSTGRES_DEFAULT_PORT = 5432

  module_function

  def validate!(environment:, test_url:, protected_urls: {})
    return nil unless environment.to_s == 'test'

    if test_url.to_s.strip.empty?
      raise UnsafeDatabaseError,
            'DATABASE_URL_TEST é obrigatória no ambiente test. ' \
            'Configure uma URL exclusiva cujo nome do banco contenha "test"; ' \
            'a suíte foi interrompida antes de conectar.'
    end

    test_target = parse_target!(test_url, variable_name: 'DATABASE_URL_TEST')

    protected_urls.each do |variable_name, protected_url|
      next if protected_url.to_s.strip.empty?

      protected_target = parse_target!(protected_url, variable_name: variable_name)
      next unless protected_target == test_target

      raise UnsafeDatabaseError,
            "DATABASE_URL_TEST aponta para o mesmo banco protegido por #{variable_name}. " \
            'Use um banco exclusivo de teste; a suíte foi interrompida antes de conectar.'
    end

    unless TEST_DATABASE_NAME_PATTERN.match?(test_target.database)
      raise UnsafeDatabaseError,
            'DATABASE_URL_TEST é insegura: o nome do banco deve identificar claramente um ambiente de test ' \
            '(por exemplo, finch_test). A suíte foi interrompida antes de conectar.'
    end

    test_url
  end

  def parse_target!(url, variable_name:)
    uri = URI.parse(url.to_s)
    adapter = normalize_adapter(uri.scheme)
    database = URI.decode_www_form_component(uri.path.to_s.sub(%r{\A/}, ''))

    if adapter.nil? || database.empty?
      raise UnsafeDatabaseError,
            "#{variable_name} precisa ser uma URL PostgreSQL completa com nome de banco. " \
            'A suíte foi interrompida antes de conectar.'
    end

    DatabaseTarget.new(
      adapter: adapter,
      host: uri.host.to_s.downcase,
      port: uri.port || POSTGRES_DEFAULT_PORT,
      database: database.downcase
    )
  rescue URI::InvalidURIError, ArgumentError
    raise UnsafeDatabaseError,
          "#{variable_name} não contém uma URL PostgreSQL válida. " \
          'A suíte foi interrompida antes de conectar.'
  end

  def normalize_adapter(scheme)
    return 'postgresql' if %w[postgres postgresql].include?(scheme.to_s.downcase)

    nil
  end
end
