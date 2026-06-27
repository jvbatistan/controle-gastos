require 'spec_helper'
require_relative '../../lib/test_database_safety'

RSpec.describe TestDatabaseSafety do
  describe '.validate!' do
    it 'rejects a missing DATABASE_URL_TEST before any database connection' do
      expect do
        described_class.validate!(
          environment: 'test',
          test_url: nil,
          protected_urls: {}
        )
      end.to raise_error(
        TestDatabaseSafety::UnsafeDatabaseError,
        /DATABASE_URL_TEST.*obrigatória/i
      )
    end

    it 'rejects the same database target used by DATABASE_URL even with different credentials or query parameters' do
      expect do
        described_class.validate!(
          environment: 'test',
          test_url: 'postgresql://test_user:test_password@db.example.com:5432/finch?sslmode=require',
          protected_urls: {
            'DATABASE_URL' => 'postgresql://app_user:app_password@DB.EXAMPLE.COM/finch?pool=5'
          }
        )
      end.to raise_error(
        TestDatabaseSafety::UnsafeDatabaseError,
        /mesmo banco protegido por DATABASE_URL/i
      )
    end

    it 'accepts a clearly named, dedicated test database' do
      test_url = 'postgresql://test_user:test_password@localhost:5432/finch_test'

      result = described_class.validate!(
        environment: 'test',
        test_url: test_url,
        protected_urls: {
          'DATABASE_URL' => 'postgresql://app_user:app_password@localhost:5432/finch_development'
        }
      )

      expect(result).to eq(test_url)
    end

    it 'does not require DATABASE_URL_TEST in development' do
      expect(
        described_class.validate!(
          environment: 'development',
          test_url: nil,
          protected_urls: {
            'DATABASE_URL' => 'postgresql://app_user:app_password@localhost:5432/finch_development'
          }
        )
      ).to be_nil
    end

    it 'rejects a database name that is not clearly identified as test' do
      expect do
        described_class.validate!(
          environment: 'test',
          test_url: 'postgresql://user:password@localhost:5432/finch_staging',
          protected_urls: {}
        )
      end.to raise_error(
        TestDatabaseSafety::UnsafeDatabaseError,
        /nome.*test/i
      )
    end
  end
end
