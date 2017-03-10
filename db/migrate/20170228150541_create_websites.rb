class CreateWebsites < ActiveRecord::Migration[5.0]
  def change
    create_table :websites do |t|
      t.string :link
      t.text :articles
      t.date :last_crawled
      t.json :result

      t.timestamps
    end
  end
end
