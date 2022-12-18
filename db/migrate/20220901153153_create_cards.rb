class CreateCards < ActiveRecord::Migration[6.0]
  def change
    create_table :cards do |t|
      t.string :name
      t.date :expiration

      t.timestamps
    end
  end
end
