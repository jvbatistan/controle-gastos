class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  self.default_shard = :local

  connects_to shards: {
    local: { writing: :local },
    supabase: { writing: :supabase }
  }
end
