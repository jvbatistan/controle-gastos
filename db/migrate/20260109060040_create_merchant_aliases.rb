class CreateMerchantAliases < ActiveRecord::Migration[6.0]
  def change
    create_table :merchant_aliases do |t|
      t.string :normalized_merchant, null: false
      t.references :category, null: false, foreign_key: true
      t.float :confidence, null: false, default: 1.0
      t.integer :source, null: false, default: 0

      t.timestamps
    end

    add_index :merchant_aliases, :normalized_merchant, unique: true
  end
end
