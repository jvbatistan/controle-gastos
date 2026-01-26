class AllowNullSuggestedCategoryOnClassificationSuggestions < ActiveRecord::Migration[6.0]
  def change
    change_column_null :classification_suggestions, :suggested_category_id, true
  end
end
