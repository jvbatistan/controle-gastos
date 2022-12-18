class AddMonthAndYearToSpend < ActiveRecord::Migration[6.0]
  def change
    add_column :spends, :month, :string
    add_column :spends, :year, :string
  end
end
