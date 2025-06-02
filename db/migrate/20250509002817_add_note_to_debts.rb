class AddNoteToDebts < ActiveRecord::Migration[6.0]
  def change
    add_column :debts, :note, :text
  end
end
