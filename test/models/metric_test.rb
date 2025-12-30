require "test_helper"

class MetricTest < ActiveSupport::TestCase
  def setup
    @metric = metrics(:europe_population_2024)
  end

  test "should be valid with all required attributes" do
    assert @metric.valid?
  end

  test "should require country" do
    @metric.country = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:country], "can't be blank"
  end

  test "should require metric_name" do
    @metric.metric_name = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:metric_name], "can't be blank"
  end

  test "should require metric_value" do
    @metric.metric_value = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:metric_value], "can't be blank"
  end

  test "should require year" do
    @metric.year = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:year], "can't be blank"
  end

  test "should require unit" do
    @metric.unit = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:unit], "can't be blank"
  end

  test "should validate uniqueness of country, metric_name, and year combination" do
    duplicate_metric = Metric.new(
      country: @metric.country,
      metric_name: @metric.metric_name,
      metric_value: 1000000,
      year: @metric.year,
      unit: "people",
      source: "Test source"
    )

    assert_not duplicate_metric.valid?
    assert_includes duplicate_metric.errors[:country], "has already been taken"
  end

  test "should allow same country and metric with different year" do
    different_year_metric = Metric.new(
      country: @metric.country,
      metric_name: @metric.metric_name,
      metric_value: 1000000,
      year: 2025,
      unit: "people",
      source: "Test source"
    )

    assert different_year_metric.valid?
  end

  test "should validate metric_value is numeric and positive" do
    @metric.metric_value = -100
    assert_not @metric.valid?
    assert_includes @metric.errors[:metric_value], "must be greater than 0"

    @metric.metric_value = "not_a_number"
    assert_not @metric.valid?
    assert_includes @metric.errors[:metric_value], "is not a number"
  end

  test "should validate year is reasonable" do
    @metric.year = 1800
    assert_not @metric.valid?
    assert_includes @metric.errors[:year], "must be greater than or equal to 1900"

    @metric.year = 2100
    assert_not @metric.valid?
    assert_includes @metric.errors[:year], "must be less than or equal to #{Date.current.year + 10}"
  end

  # Test scopes
  test "for_country scope should return metrics for specific country" do
    europe_metrics = Metric.for_country("europe")
    assert europe_metrics.all? { |m| m.country == "europe" }
    assert_includes europe_metrics, metrics(:europe_population_2024)
    assert_includes europe_metrics, metrics(:europe_gdp_2024)
  end

  test "for_metric scope should return metrics for specific metric type" do
    population_metrics = Metric.for_metric("population")
    assert population_metrics.all? { |m| m.metric_name == "population" }
    assert_includes population_metrics, metrics(:europe_population_2024)
    assert_includes population_metrics, metrics(:usa_population_2024)
  end

  test "for_year scope should return metrics for specific year" do
    metrics_2024 = Metric.for_year(2024)
    assert metrics_2024.all? { |m| m.year == 2024 }
    assert_includes metrics_2024, metrics(:europe_population_2024)
    assert_includes metrics_2024, metrics(:usa_gdp_2024)
  end

  test "latest_for_country_and_metric should return most recent metric" do
    latest = Metric.latest_for_country_and_metric("europe", "population")
    assert_equal metrics(:europe_population_2024), latest

    # Test when no data exists
    no_data = Metric.latest_for_country_and_metric("nonexistent", "population")
    assert_nil no_data
  end

  # Test display methods
  test "formatted_value should format values appropriately" do
    # Population values (millions)
    population_metric = metrics(:europe_population_2024)
    assert_equal "745.1M", population_metric.formatted_value

    # GDP values (thousands with currency)
    gdp_metric = metrics(:usa_gdp_2024)
    assert_equal "$75,492", gdp_metric.formatted_value

    # Life expectancy (one decimal place)
    life_metric = metrics(:europe_life_expectancy_2024)
    assert_equal "78.5", life_metric.formatted_value
  end

  test "display_name should return human readable country names" do
    assert_equal "Europe", metrics(:europe_population_2024).display_name
    assert_equal "United States", metrics(:usa_population_2024).display_name
    assert_equal "China", metrics(:china_population_2024).display_name
    assert_equal "India", metrics(:india_population_2024).display_name
  end

  test "metric_display_name should return human readable metric names" do
    assert_equal "Population", metrics(:europe_population_2024).metric_display_name
    assert_equal "GDP per Capita (PPP)", metrics(:usa_gdp_2024).metric_display_name
    assert_equal "Life Expectancy", metrics(:europe_life_expectancy_2024).metric_display_name
  end

  # Test data integrity
  test "should maintain data consistency across related metrics" do
    # Verify that we have both population and GDP data for key countries
    key_countries = [ "europe", "usa", "china", "india" ]

    key_countries.each do |country|
      population = Metric.latest_for_country_and_metric(country, "population")
      gdp = Metric.latest_for_country_and_metric(country, "gdp_per_capita_ppp")

      assert population, "Missing population data for #{country}"
      assert gdp, "Missing GDP data for #{country}"
      assert_equal population.year, gdp.year, "Year mismatch for #{country} between population and GDP"
    end
  end

  test "european countries should have reasonable population adjustments" do
    # Test that transcontinental countries exist in fixtures
    russia = metrics(:russia_population_2024)
    turkey = metrics(:turkey_population_2024)

    assert russia.present?, "Russia should be in fixtures for transcontinental testing"
    assert turkey.present?, "Turkey should be in fixtures for transcontinental testing"

    # Verify populations are reasonable
    assert russia.metric_value > 100_000_000, "Russia population should be substantial"
    assert turkey.metric_value > 80_000_000, "Turkey population should be substantial"
  end

  # Test edge cases
  test "should handle very large numbers correctly" do
    large_metric = Metric.new(
      country: "test_country",
      metric_name: "test_metric",
      metric_value: 1_000_000_000_000, # 1 trillion
      year: 2024,
      unit: "test_unit",
      source: "Test"
    )

    assert large_metric.valid?
    assert_equal 1_000_000_000_000, large_metric.metric_value
  end

  test "should handle decimal values correctly" do
    decimal_metric = Metric.new(
      country: "test_country",
      metric_name: "test_rate",
      metric_value: 12.345,
      year: 2024,
      unit: "percentage",
      source: "Test"
    )

    assert decimal_metric.valid?
    assert_in_delta 12.345, decimal_metric.metric_value.to_f, 0.01
  end
end
