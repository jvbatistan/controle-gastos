class RemoveImageAndColorFromCards < ActiveRecord::Migration[6.1]
  def change
    remove_column :cards, :image, :string
    remove_column :cards, :color, :string
  end
end
