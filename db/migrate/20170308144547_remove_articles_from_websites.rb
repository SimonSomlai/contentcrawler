class RemoveArticlesFromWebsites < ActiveRecord::Migration[5.0]
  def change
    remove_column :websites, :articles
    remove_column :websites, :result
  end
end
