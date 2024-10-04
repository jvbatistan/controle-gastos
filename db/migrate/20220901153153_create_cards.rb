class CreateCards < ActiveRecord::Migration[6.0]
  def change
    create_table :cards do |t|
      t.string  :name
      t.integer :due_date
      t.integer :closing_date
      t.integer :limit
      t.string  :image
      t.string  :color
      
      t.timestamps
    end
  end
end
