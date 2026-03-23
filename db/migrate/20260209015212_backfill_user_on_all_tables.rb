class BackfillUserOnAllTables < ActiveRecord::Migration[6.0]
  def up
    user_id = select_value("SELECT id FROM users ORDER BY id ASC LIMIT 1")
    return unless user_id.present?

    %w[cards categories transactions merchant_aliases classification_suggestions].each do |table|
      execute <<~SQL
        UPDATE #{table}
        SET user_id = #{user_id}
        WHERE user_id IS NULL
      SQL
    end
  end

  def down
    # irreversível (dados)
  end
end
