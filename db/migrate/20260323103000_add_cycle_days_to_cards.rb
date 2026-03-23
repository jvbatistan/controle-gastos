class AddCycleDaysToCards < ActiveRecord::Migration[6.1]
  def up
    add_column :cards, :due_day, :integer
    add_column :cards, :closing_day, :integer

    execute <<~SQL
      UPDATE cards
      SET due_day = due_date
      WHERE due_day IS NULL AND due_date IS NOT NULL
    SQL
  end

  def down
    remove_column :cards, :due_day
    remove_column :cards, :closing_day
  end
end
