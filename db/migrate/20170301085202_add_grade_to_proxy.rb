class AddGradeToProxy < ActiveRecord::Migration[5.0]
  def change
    add_column :proxies, :grade, :integer, index: true
  end
end
