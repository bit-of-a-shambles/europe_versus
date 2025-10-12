class DropStatisticsAndPendingStatisticsTables < ActiveRecord::Migration[8.0]
  def change
    drop_table :statistics, if_exists: true do |t|
      t.string :category, null: false
      t.string :metric, null: false
      t.decimal :europe_value, precision: 15, scale: 2
      t.decimal :us_value, precision: 15, scale: 2
      t.decimal :india_value, precision: 15, scale: 2
      t.decimal :china_value, precision: 15, scale: 2
      t.string :unit
      t.text :description
      t.string :source
      t.integer :year
      t.timestamps null: false
    end

    drop_table :pending_statistics, if_exists: true do |t|
      t.string :category, null: false
      t.string :metric, null: false
      t.decimal :europe_value, precision: 15, scale: 2
      t.decimal :us_value, precision: 15, scale: 2
      t.decimal :india_value, precision: 15, scale: 2
      t.decimal :china_value, precision: 15, scale: 2
      t.string :unit
      t.text :description
      t.string :source
      t.integer :year
      t.string :status, default: "pending"
      t.timestamps null: false
    end
  end
end
