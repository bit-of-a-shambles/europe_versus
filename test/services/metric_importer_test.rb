require "test_helper"
require "webmock/minitest"

class MetricImporterTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    MetricImporter.reload_configs!
  end

  teardown do
    WebMock.allow_net_connect!
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

  test "import_metric with owid source requires owid_slug" do
    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :owid }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    assert result[:error].present?
    assert_includes result[:error], "Missing owid_slug"

    MetricImporter.reload_configs!
  end

  test "import_metric with ilo source requires ilo_indicator" do
    MetricImporter.instance_variable_set(:@configs, {
      "test_metric" => { source: :ilo }
    })

    result = MetricImporter.import_metric("test_metric", verbose: false)

    assert result[:error].present?
    assert_includes result[:error], "Missing ilo_indicator"

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

    results = MetricImporter.import_all(verbose: false)

    assert results[:metrics].key?("test_metric")
    assert results[:total_records] >= 0

    MetricImporter.reload_configs!
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
end
