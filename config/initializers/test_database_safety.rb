require Rails.root.join('lib/test_database_safety')

TestDatabaseSafety.validate!(
  environment: Rails.env,
  test_url: ENV['DATABASE_URL_TEST'],
  protected_urls: {
    'DATABASE_URL' => ENV['DATABASE_URL'],
    'DATABASE_URL_DEVEL' => ENV['DATABASE_URL_DEVEL'],
    'DATABASE_URL_DEVELOPMENT' => ENV['DATABASE_URL_DEVELOPMENT'],
    'DATABASE_URL_PRODUCTION' => ENV['DATABASE_URL_PRODUCTION']
  }
)
