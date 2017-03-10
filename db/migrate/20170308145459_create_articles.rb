class CreateArticles < ActiveRecord::Migration[5.0]
  def change
    create_table :articles do |t|
      t.string :link, index: true 
      t.integer :facebook_shares
      t.integer :twitter_shares
      t.integer :pinterest_pins
      t.integer :total_shares
      t.integer :linkedin_shares
      t.integer :google_shares
      t.integer :comments
      t.integer :website_id

      t.timestamps
    end
  end
end
