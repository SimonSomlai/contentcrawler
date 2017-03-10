class AddIndexToCrawled < ActiveRecord::Migration[5.0]
  def change
    add_index :articles, :crawled
  end
end
