class AddStatusToWebsite < ActiveRecord::Migration[5.0]
  def change
    add_column :websites, :status, :boolean, default: false
  end
end
