require 'rails_helper'

RSpec.describe 'schema dump policy' do
  it 'does not generate schema dumps automatically after shard migrations' do
    expect(ActiveRecord::Base.dump_schema_after_migration).to be(false)
  end
end
