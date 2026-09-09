require_relative 'boot'

require 'logger'
require 'rails/all'
require_relative '../lib/data_environment_middleware'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ControleDeGastos
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.active_record.legacy_connection_handling = false
    config.active_record.dump_schema_after_migration = false
    config.middleware.insert_after ActionDispatch::Session::CookieStore, DataEnvironmentMiddleware

    config.i18n.default_locale = :"pt-BR"
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
