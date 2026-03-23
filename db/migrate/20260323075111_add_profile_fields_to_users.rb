class AddProfileFieldsToUsers < ActiveRecord::Migration[6.1]
  def up
    add_column :users, :name, :string
    add_column :users, :active, :boolean, default: true, null: false

    execute <<~SQL
      UPDATE users
      SET name = COALESCE(NULLIF(split_part(email, '@', 1), ''), 'Usuário')
      WHERE name IS NULL
    SQL

    change_column_null :users, :name, false
  end

  def down
    remove_column :users, :active
    remove_column :users, :name
  end
end
