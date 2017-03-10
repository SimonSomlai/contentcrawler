class CreateUsersWebsitesJoinTable < ActiveRecord::Migration[5.0]
  def change
    create_table :users_websites, id: false do |t|
      t.integer :user_id
      t.integer :website_id
    end
  end
end
