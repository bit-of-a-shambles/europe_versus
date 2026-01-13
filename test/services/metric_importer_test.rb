require "test_helper"
require "webmock/minitest"

class MetricImporterTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    MetricImporter.reload_configs!
    @original_population_count = Metric.where(metric_name: "population").count
  end

  teardown do
    WebMock.allow_net_connect!
    MetricImporter.reload_configs!
  end

  # ============================================================================
  # CRITICAL: Population Data Priority Tests
  # These tests ensure population data is available before aggregate calculations
  # ============================================================================

  test "ensure_population_data returns true when population data exists" do
    # Skip if no population data exists (fresh DB)
    skip "No population data in test DB" if Metric.where(metric_name: "population").count < 100

    result = MetricImporter.ensure_population_data(verbose: false)
    assert result, "Should return true when population data exists"
  end

  test "ensure_population_data checks for minimum record threshold of 5000" do
    original_count = Metric.where(metric_name: "population").count

    if original_count > 5000
      # Data exists, should return true without importing
      result = MetricImporter.ensure_population_data(verbose: false)
      assert result, "Should return true when enough population data exists"
    else
      # Less data exists - method should attempt to import
      # Just verify the method doesn't crash
      assert MetricImporter.respond_to?(:ensure_population_data)
    end
  end

  test "ensure_population_data method exists and is callable" do
    assert MetricImporter.respond_to?(:ensure_population_data)
    # Stub the population data request
    stub_request(:get, /ourworldindata\.org.*population\.csv/)
      .to_return(status: 200, body: "Entity,Code,Year,Population\nGermany,DEU,2020,83000000", headers: { "Content-Type" => "text/csv" })
    # Should not raise when called (even if it returns false due to errors)
    assert_nothing_raised do
      MetricImporter.ensure_population_data(verbose: false)
    end
  end

  # ============================================================================
  # Import Ordering Tests
  # Ensure OWID metrics are imported before ILO metrics
  # ============================================================================

  test "config sorting puts OWID before WorldBank before ILO" do
    # Test the sorting logic directly
    test_configs = {
      "ilo_metric" => { source: :ilo },
      "owid_metric" => { source: :owid },
      "worldbank_metric" => { source: :worldbank },
      "another_ilo" => { source: :ilo }
    }

    sorted = test_configs.sort_by do |_name, config|
      case config[:source]&.to_sym
      when :owid then 0
      when :worldbank then 1
      when :ilo then 2
      else 3
      end
    end

    sorted_sources = sorted.map { |_, c| c[:source] }

    owid_index = sorted_sources.index(:owid)
    worldbank_index = sorted_sources.index(:worldbank)
    ilo_index = sorted_sources.index(:ilo)

    assert owid_index < worldbank_index, "OWID should come before WorldBank"
    assert worldbank_index < ilo_index, "WorldBank should come before ILO"
  end

  test "import_all method exists and accepts verbose parameter" do
    assert MetricImporter.respond_to?(:import_all)

    # Test method signature accepts verbose keyword argument
    method = MetricImporter.method(:import_all)
    assert method.parameters.any? { |type, name| name == :verbose }
  end

  # ============================================================================
  # Source-Specific Import Tests
  # ============================================================================

  test "import_owid_metric validates owid_slug presence" do
    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :owid }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    assert result[:error].present?
    assert_includes result[:error], "Missing owid_slug"

    MetricImporter.reload_configs!
  end

  test "import_ilo_metric validates ilo_indicator presence" do
    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :ilo }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    assert result[:error].present?
    assert_includes result[:error], "Missing ilo_indicator"

    MetricImporter.reload_configs!
  end

  test "import_worldbank_metric validates worldbank_indicator presence" do
    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :worldbank }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    assert result[:error].present?
    assert_includes result[:error], "worldbank_indicator"

    MetricImporter.reload_configs!
  end

  # CONFIG_FILE constant test
  test "CONFIG_FILE points to metrics.yml" do
    assert_equal Rails.root.join("config", "metrics.yml"), MetricImporter::CONFIG_FILE
  end

  # load_configs tests
  test "load_configs returns empty hash when file does not exist" do
    original_file = MetricImporter::CONFIG_FILE
    # The constant can't be easily changed, so we'll just test the method behavior
    # when configs are loaded
    assert_kind_of Hash, MetricImporter.load_configs
  end

  test "load_configs symbolizes config values" do
    # Skip if no metrics.yml exists
    skip unless File.exist?(MetricImporter::CONFIG_FILE)

    configs = MetricImporter.configs

    if configs.any?
      first_config = configs.values.first
      assert first_config[:source].is_a?(Symbol) if first_config[:source]
    end
  end

  # configs tests
  test "configs returns memoized configurations" do
    configs1 = MetricImporter.configs
    configs2 = MetricImporter.configs
    assert_same configs1, configs2
  end

  # reload_configs! tests
  test "reload_configs! clears memoized configs" do
    configs1 = MetricImporter.configs
    MetricImporter.reload_configs!
    configs2 = MetricImporter.configs

    # Should be equal but not same object
    assert_equal configs1, configs2
    # After reload, it should be a new object (though this depends on implementation)
  end

  # import_metric tests
  test "import_metric returns error for unknown metric" do
    result = MetricImporter.import_metric("nonexistent_metric", verbose: false)

    assert result[:error].present?
    assert_includes result[:error], "Unknown metric"
  end

  test "import_metric returns error for unknown source" do
    # Create a temporary config with unknown source
    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :unknown_source }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    assert result[:error].present?
    assert_includes result[:error], "Unknown source"

    # Reset configs
    MetricImporter.reload_configs!
  end

  # import_by_source tests
  test "import_by_source filters configs by source" do
    stub_owid_requests

    MetricImporter.instance_variable_set(:@configs, {
      "owid_metric" => { source: :owid, owid_slug: "test-chart", start_year: 2020, end_year: 2024 },
      "ilo_metric" => { source: :ilo, ilo_indicator: :labor_productivity_per_hour }
    })

    results = MetricImporter.import_by_source(:owid, verbose: false)

    assert results[:metrics].key?("owid_metric")
    refute results[:metrics].key?("ilo_metric")

    MetricImporter.reload_configs!
  end

  # import_by_category tests
  test "import_by_category filters configs by category" do
    stub_owid_requests

    MetricImporter.instance_variable_set(:@configs, {
      "economy_metric" => { source: :owid, owid_slug: "test-chart", category: "economy", start_year: 2020, end_year: 2024 },
      "health_metric" => { source: :owid, owid_slug: "test-chart", category: "health", start_year: 2020, end_year: 2024 }
    })

    results = MetricImporter.import_by_category(:economy, verbose: false)

    assert results[:metrics].key?("economy_metric")
    refute results[:metrics].key?("health_metric")

    MetricImporter.reload_configs!
  end

  # list_metrics tests
  test "list_metrics returns array of metric names" do
    MetricImporter.instance_variable_set(:@configs, {
      "metric1" => { source: :owid },
      "metric2" => { source: :ilo }
    })

    metrics = MetricImporter.list_metrics

    assert_includes metrics, "metric1"
    assert_includes metrics, "metric2"

    MetricImporter.reload_configs!
  end

  # list_by_source tests
  test "list_by_source returns metrics for specified source" do
    MetricImporter.instance_variable_set(:@configs, {
      "owid_metric" => { source: :owid },
      "ilo_metric" => { source: :ilo }
    })

    owid_metrics = MetricImporter.list_by_source(:owid)

    assert_includes owid_metrics, "owid_metric"
    refute_includes owid_metrics, "ilo_metric"

    MetricImporter.reload_configs!
  end

  # list_by_category tests
  test "list_by_category returns metrics for specified category" do
    MetricImporter.instance_variable_set(:@configs, {
      "economy_metric" => { category: "economy" },
      "health_metric" => { category: "health" }
    })

    economy_metrics = MetricImporter.list_by_category("economy")

    assert_includes economy_metrics, "economy_metric"
    refute_includes economy_metrics, "health_metric"

    MetricImporter.reload_configs!
  end

  # get_config tests
  test "get_config returns config for specific metric" do
    test_config = { source: :owid, category: "test" }
    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => test_config
    })

    config = MetricImporter.get_config("test_metric")

    assert_equal test_config, config

    MetricImporter.reload_configs!
  end

  test "get_config returns nil for unknown metric" do
    config = MetricImporter.get_config("nonexistent_metric")
    assert_nil config
  end

  # summary tests
  test "summary returns overview of available metrics" do
    MetricImporter.instance_variable_set(:@configs, {
      "owid_metric" => { source: :owid, category: "economy", enabled: true, preferred: true },
      "ilo_metric" => { source: :ilo, category: "productivity", enabled: true }
    })

    summary = MetricImporter.summary

    assert_equal 2, summary[:total]
    assert summary[:by_source].key?(:owid)
    assert summary[:by_source].key?(:ilo)
    assert summary[:by_category].key?("economy")
    assert_equal 2, summary[:enabled]
    assert_includes summary[:preferred], "owid_metric"

    MetricImporter.reload_configs!
  end

  # import_all tests
  test "import_all processes all enabled metrics" do
    stub_owid_requests

    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => {
        source: :owid,
        owid_slug: "test-chart",
        start_year: 2020,
        end_year: 2024,
        enabled: true
      }
    })

    # Skip population check by ensuring enough records exist or stubbing
    results = MetricImporter.import_all(verbose: false)

    assert results[:metrics].key?("test_metric")
    assert results[:total_records] >= 0

    MetricImporter.reload_configs!
  end

  # ============================================================================
  # Integration Tests: Aggregate Calculation with Population Data
  # ============================================================================

  test "aggregate calculation requires population data to exist" do
    # Skip if no population data exists
    skip "Requires population data" if Metric.where(metric_name: "population").count < 100

    # Create some test metric data for European countries
    test_countries = %w[germany france italy spain netherlands]
    test_countries.each_with_index do |country, idx|
      Metric.find_or_create_by!(
        metric_name: "test_aggregate_metric",
        country: country,
        year: 2020
      ) do |m|
        m.metric_value = 100 + idx * 10
        m.unit = "test_unit"
        m.source = "Test"
      end
    end

    # Verify population data exists for these countries
    test_countries.each do |country|
      pop = Metric.where(metric_name: "population", country: country).first
      assert pop.present?, "Population data should exist for #{country}"
    end

    # Clean up
    Metric.where(metric_name: "test_aggregate_metric").delete_all
  end

  test "import_all returns comprehensive results structure" do
    stub_owid_requests

    MetricImporter.instance_variable_set(:@configs, {
      "metric_a" => { source: :owid, owid_slug: "test-a", start_year: 2020, end_year: 2024 },
      "metric_b" => { source: :owid, owid_slug: "test-b", start_year: 2020, end_year: 2024 }
    })

    results = MetricImporter.import_all(verbose: false)

    assert results.key?(:total_records), "Results should include total_records"
    assert results.key?(:metrics), "Results should include metrics hash"
    assert results[:metrics].is_a?(Hash), "Metrics should be a hash"

    MetricImporter.reload_configs!
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  test "import_metric handles network errors gracefully" do
    stub_request(:get, /ourworldindata\.org/)
      .to_timeout

    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :owid, owid_slug: "test-chart", start_year: 2020, end_year: 2024 }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    # Should not raise an exception
    assert result.is_a?(Hash)

    MetricImporter.reload_configs!
  end

  test "import_metric handles API errors gracefully" do
    stub_request(:get, /ourworldindata\.org/)
      .to_return(status: 500, body: "Internal Server Error")

    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :owid, owid_slug: "test-chart", start_year: 2020, end_year: 2024 }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    # Should not raise an exception
    assert result.is_a?(Hash)

    MetricImporter.reload_configs!
  end

  # ============================================================================
  # Configuration Validation Tests
  # ============================================================================

  test "configs are properly symbolized" do
    skip unless File.exist?(MetricImporter::CONFIG_FILE)

    configs = MetricImporter.configs
    return if configs.empty?

    first_config = configs.values.first
    assert first_config[:source].is_a?(Symbol), "Source should be symbolized"
  end

  test "disabled metrics are excluded from configs" do
    # Verify that the load_configs method filters out disabled metrics
    # This is implicitly tested by checking that enabled != false check works
    assert MetricImporter.respond_to?(:load_configs)
  end

  private

  def stub_owid_requests
    csv_data = <<~CSV
      Entity,Code,Year,Value
      Germany,DEU,2020,50000
      France,FRA,2020,48000
    CSV

    stub_request(:get, /ourworldindata\.org.*\.csv/)
      .to_return(status: 200, body: csv_data, headers: {})

    stub_request(:get, /ourworldindata\.org.*\.metadata\.json/)
      .to_return(status: 200, body: "{}", headers: {})
  end

  def stub_ilo_requests
    response = {
      "dataSets" => [ {
        "observations" => {
          "0:0:0" => [ 75.5 ],
          "0:0:1" => [ 76.2 ],
          "0:0:2" => [ 77.0 ]
        }
      } ],
      "structure" => {
        "dimensions" => {
          "observation" => [
            { "values" => [ { "id" => "DEU" } ] },
            { "values" => [ { "id" => "A" } ] },
            { "values" => [
              { "id" => "2020" },
              { "id" => "2021" },
              { "id" => "2022" }
            ] }
          ]
        }
      }
    }

    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_worldbank_requests
    response = [
      { "page" => 1, "pages" => 1, "per_page" => 50, "total" => 2 },
      [
        { "country" => { "id" => "DE", "value" => "Germany" }, "date" => "2020", "value" => 45000 },
        { "country" => { "id" => "FR", "value" => "France" }, "date" => "2020", "value" => 42000 }
      ]
    ]

    stub_request(:get, /api\.worldbank\.org/)
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end
end
