require "test_helper"

class OwidMetricImporterTest < ActiveSupport::TestCase
  def setup
    @importer = OwidMetricImporter
    @test_metric = "life_satisfaction"
    # Clear runtime configs before each test
    @importer.runtime_configs = {}
    # Reload configs from YAML
    @importer.reload_configs!
  end

  # Test YAML loading
  test "should load configs from YAML file" do
    configs = @importer.yaml_configs

    assert configs.is_a?(Hash), "Should return a hash"
    assert configs.size > 0, "Should load at least one metric"

    # Check that expected metrics are loaded
    assert configs["health_expenditure_gdp_percent"].present?, "Should load health_expenditure_gdp_percent"
    assert configs["life_satisfaction"].present?, "Should load life_satisfaction"
  end

  test "yaml_configs should properly structure loaded metrics" do
    @importer.yaml_configs.each do |metric_name, config|
      assert metric_name.is_a?(String), "Metric name should be a string"
      assert config.is_a?(Hash), "Config should be a hash"

      # Check required fields
      assert config[:owid_slug].present?, "#{metric_name} should have owid_slug"
      assert config[:start_year].present?, "#{metric_name} should have start_year"
      assert config[:end_year].present?, "#{metric_name} should have end_year"
      assert config[:unit].present?, "#{metric_name} should have unit"
      assert config[:description].present?, "#{metric_name} should have description"
      assert config[:category].present?, "#{metric_name} should have category"
      assert config[:aggregation_method].present?, "#{metric_name} should have aggregation_method"

      # Check field types
      assert config[:owid_slug].is_a?(String), "owid_slug should be a string"
      assert config[:start_year].is_a?(Integer), "start_year should be an integer"
      assert config[:end_year].is_a?(Integer), "end_year should be an integer"
      assert config[:unit].is_a?(String), "unit should be a string"
      assert config[:description].is_a?(String), "description should be a string"
      assert config[:category].is_a?(String), "category should be a string"
      assert config[:aggregation_method].is_a?(Symbol), "aggregation_method should be a symbol"

      # Check valid categories
      valid_categories = %w[economy social development health environment innovation]
      assert valid_categories.include?(config[:category]),
             "#{metric_name} category should be one of #{valid_categories}"      # Check valid aggregation methods
      valid_methods = [ :population_weighted, :sum, :average ]
      assert valid_methods.include?(config[:aggregation_method]),
             "#{metric_name} aggregation_method should be one of #{valid_methods}"

      # Check year ranges are sensible
      assert config[:start_year] >= 1900, "#{metric_name} start_year should be reasonable"
      assert config[:end_year] <= 2100, "#{metric_name} end_year should be reasonable"
      assert config[:start_year] <= config[:end_year], "#{metric_name} start_year should be before end_year"
    end
  end

  test "reload_configs! should refresh from YAML" do
    initial_configs = @importer.yaml_configs

    # Reload
    @importer.reload_configs!
    reloaded_configs = @importer.yaml_configs

    # Should have same metrics
    assert_equal initial_configs.keys.sort, reloaded_configs.keys.sort
  end

  # Test helper methods
  test "list_metrics should return all metric names" do
    metrics = @importer.list_metrics

    assert metrics.is_a?(Array), "Should return an array"
    assert metrics.size > 0, "Should return at least one metric"
    assert metrics.all? { |m| m.is_a?(String) }, "All items should be strings"

    # Check that it includes YAML metrics
    assert metrics.include?("life_satisfaction"), "Should include life_satisfaction"
  end

  test "get_config should return configuration for valid metric" do
    config = @importer.get_config(@test_metric)

    assert config.is_a?(Hash), "Should return a hash"
    assert config[:owid_slug].present?, "Should have owid_slug"
    assert config[:description].present?, "Should have description"
  end

  test "get_config should return nil for invalid metric" do
    config = @importer.get_config("nonexistent_metric")

    assert_nil config, "Should return nil for nonexistent metric"
  end

  # Test import_metric method
  test "import_metric should return error for invalid metric name" do
    result = @importer.import_metric("nonexistent_metric", verbose: false)

    assert result.is_a?(Hash), "Should return a hash"
    assert result[:error].present?, "Should have error message"
    assert_includes result[:error], "Unknown metric", "Error should mention unknown metric"
  end

  test "import_metric should handle valid metric (integration test)" do
    skip "Integration test - enable to test real API calls"

    # Clear existing data for this metric
    Metric.where(metric_name: @test_metric).delete_all

    result = @importer.import_metric(@test_metric, verbose: false)

    assert result.is_a?(Hash), "Should return a hash"
    assert result[:success], "Should be successful"
    assert result[:stored_count] > 0, "Should create some records"

    # Verify data was actually stored
    records = Metric.where(metric_name: @test_metric)
    assert records.count > 0, "Should have created metric records"

    # Verify Europe aggregate was calculated
    europe_record = Metric.for_country("europe").for_metric(@test_metric).latest
    assert europe_record.present?, "Should have Europe aggregate"
    assert europe_record.metric_value > 0, "Europe value should be positive"
  end

  # Test import_category method
  test "import_category should accept array of metrics" do
    # Test with empty array
    result = @importer.import_category([], verbose: false)
    assert result.nil? || result.is_a?(Array), "Should handle empty array gracefully"

    # Test with invalid metrics - should not crash
    assert_nothing_raised do
      @importer.import_category([ "nonexistent_metric" ], verbose: false)
    end
  end

  test "import_category should handle multiple metrics" do
    skip "Integration test - enable to test real API calls"

    metrics = [ "child_mortality_rate", "electricity_access" ]
    @importer.import_category(metrics, verbose: false)

    # Should complete without error
    assert true, "Should handle multiple metrics"
  end

  # Test add_metric_config method
  test "add_metric_config should accept keyword arguments and store in runtime" do
    new_config = @importer.add_metric_config(
      "test_metric_unique",
      owid_slug: "test-metric",
      start_year: 2000,
      end_year: 2024,
      unit: "test unit",
      description: "Test metric for testing",
      aggregation_method: :average
    )

    # Verify it returns a config hash
    assert new_config.is_a?(Hash), "Should return a config hash"
    assert_equal "test-metric", new_config[:owid_slug]

    # Verify it was added to runtime_configs
    assert @importer.runtime_configs["test_metric_unique"].present?, "Should add to runtime configs"
  end

  test "add_metric_config should require owid_slug" do
    assert_raises(ArgumentError) do
      @importer.add_metric_config("test_metric")
    end
  end

  # Test backward compatibility with fallback configs
  test "should use fallback configs if YAML file missing" do
    # This tests the FALLBACK_CONFIGS constant exists
    assert defined?(@importer::FALLBACK_CONFIGS), "Should have FALLBACK_CONFIGS"
    assert @importer::FALLBACK_CONFIGS.is_a?(Hash), "FALLBACK_CONFIGS should be a hash"
  end

  # Test public interface
  test "should expose expected public methods" do
    assert @importer.respond_to?(:import_metric), "Should have import_metric method"
    assert @importer.respond_to?(:import_all_metrics), "Should have import_all_metrics method"
    assert @importer.respond_to?(:import_category), "Should have import_category method"
    assert @importer.respond_to?(:list_metrics), "Should have list_metrics method"
    assert @importer.respond_to?(:get_config), "Should have get_config method"
    assert @importer.respond_to?(:add_metric_config), "Should have add_metric_config method"
    assert @importer.respond_to?(:reload_configs!), "Should have reload_configs! method"
    assert @importer.respond_to?(:yaml_configs), "Should have yaml_configs method"
  end

  # Test configuration details for known metrics
  test "life_satisfaction should have correct configuration" do
    config = @importer.get_config("life_satisfaction")

    assert_equal "happiness-cantril-ladder", config[:owid_slug]
    assert_equal "score (0-10)", config[:unit]
    assert_equal :population_weighted, config[:aggregation_method]
    assert config[:start_year] >= 2000, "Should have reasonable start year"
  end

  test "health_expenditure_gdp_percent should have correct configuration" do
    config = @importer.get_config("health_expenditure_gdp_percent")

    assert_equal "total-healthcare-expenditure-gdp", config[:owid_slug]
    assert_equal "% of GDP", config[:unit]
    assert_equal :population_weighted, config[:aggregation_method]
    assert config[:start_year] >= 2000, "Should have reasonable start year"
  end

  # Test all_configs includes both YAML and runtime
  test "all_configs should merge yaml and runtime configs" do
    # Add a runtime config
    @importer.add_metric_config(
      "runtime_test",
      owid_slug: "test-slug",
      start_year: 2020,
      end_year: 2024,
      unit: "test",
      description: "Test",
      aggregation_method: :average
    )

    all = @importer.all_configs

    # Should include YAML configs
    assert all["life_satisfaction"].present?, "Should include YAML configs"

    # Should include runtime configs
    assert all["runtime_test"].present?, "Should include runtime configs"
  end
end
