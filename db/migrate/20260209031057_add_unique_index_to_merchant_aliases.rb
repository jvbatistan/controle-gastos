class AddUniqueIndexToMerchantAliases < ActiveRecord::Migration[6.0]
  def change
    remove_index :merchant_aliases, :normalized_merchant if index_exists?(:merchant_aliases, :normalized_merchant)
    add_index :merchant_aliases, [:user_id, :normalized_merchant], unique: true
  end
end
