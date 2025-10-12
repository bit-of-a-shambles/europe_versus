class AddDescriptionToMetrics < ActiveRecord::Migration[8.0]
  def change
    add_column :metrics, :description, :text
  end
end
