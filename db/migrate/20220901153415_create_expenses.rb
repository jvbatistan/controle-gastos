class CreateExpenses < ActiveRecord::Migration[6.0]
  def change
    create_table :expenses do |t|
      t.string     :description
      t.float      :value
      t.string     :month
      t.string     :year
      t.boolean    :paid
      t.boolean    :has_installment
      t.integer    :current_installment
      t.integer    :final_installment
      t.string     :responsible
      t.references :card, null: false, foreign_key: true

      t.timestamps
    end
  end
end
