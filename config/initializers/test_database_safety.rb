require Rails.root.join('lib/test_database_safety')

protected_database_urls = {
  'DATABASE_URL' => ENV['DATABASE_URL'],
  'DATABASE_URL_DEVEL' => ENV['DATABASE_URL_DEVEL'],
  'DATABASE_URL_DEVELOPMENT' => ENV['DATABASE_URL_DEVELOPMENT'],
  'DATABASE_URL_LOCAL' => ENV['DATABASE_URL_LOCAL'],
  'DATABASE_URL_PRODUCTION' => ENV['DATABASE_URL_PRODUCTION']
}

TestDatabaseSafety.validate!(
  environment: Rails.env,
  test_url: ENV['DATABASE_URL_TEST'],
  protected_urls: protected_database_urls
)

if ENV['DATABASE_URL_TEST_SUPABASE'].present?
  TestDatabaseSafety.validate!(
    environment: Rails.env,
    test_url: ENV['DATABASE_URL_TEST_SUPABASE'],
    protected_urls: protected_database_urls,
    variable_name: 'DATABASE_URL_TEST_SUPABASE'
  )
end
