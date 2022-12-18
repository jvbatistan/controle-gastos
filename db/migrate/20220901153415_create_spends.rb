class CreateSpends < ActiveRecord::Migration[6.0]
  def change
    create_table :spends do |t|
      t.string :description
      t.float :value
      t.boolean :paid
      t.references :card, null: false, foreign_key: true

      t.timestamps
    end
  end
end
