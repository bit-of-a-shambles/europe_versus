class AddCoverageToMetrics < ActiveRecord::Migration[8.0]
  def change
    # Coverage percentage (0.0 to 1.0) for aggregate metrics
    # - null for individual country metrics
    # - 1.0 means all countries had data for that year
    # - 0.5 means 50% of countries had data (some used forward-filled values)
    add_column :metrics, :coverage, :decimal, precision: 5, scale: 4
  end
end
