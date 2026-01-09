class ChangeDebtValueToDecimal < ActiveRecord::Migration[6.0]
  def up
    change_column :debts, :value, :decimal, precision: 12, scale: 2
  end

  def down
    change_column :debts, :value, :float
  end
end
