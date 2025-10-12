class CreateMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :metrics do |t|
      t.string :country, null: false
      t.string :metric_name, null: false
      t.decimal :metric_value, precision: 15, scale: 2
      t.integer :year, null: false
      t.string :unit
      t.string :source
      t.text :description

      t.timestamps
    end
    
    add_index :metrics, [:country, :metric_name, :year], unique: true
    add_index :metrics, :metric_name
    add_index :metrics, :year
  end
end
