class AddCrawledToArticles < ActiveRecord::Migration[5.0]
  def change
    add_column :articles, :crawled, :boolean, default: false, index: true
  end
end
