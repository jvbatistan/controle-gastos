class BackfillUserOnAllTables < ActiveRecord::Migration[6.0]
  def up
    user = User.first

    execute "UPDATE cards SET user_id = #{user.id} WHERE user_id IS NULL"
    execute "UPDATE categories SET user_id = #{user.id} WHERE user_id IS NULL"
    execute "UPDATE transactions SET user_id = #{user.id} WHERE user_id IS NULL"
    execute "UPDATE classification_suggestions SET user_id = #{user.id} WHERE user_id IS NULL"
    execute "UPDATE merchant_aliases SET user_id = #{user.id} WHERE user_id IS NULL"
  end

  def down
    # irreversível (dados)
  end
end
