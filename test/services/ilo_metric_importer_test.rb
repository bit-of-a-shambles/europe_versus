require "test_helper"
require "webmock/minitest"

class IloMetricImporterTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  teardown do
    WebMock.allow_net_connect!
    # Clean up test data
    Metric.where("metric_name LIKE ?", "labor_productivity%").delete_all
  end

  # METRIC_MAPPINGS tests
  test "METRIC_MAPPINGS contains labor productivity metrics" do
    assert IloMetricImporter::METRIC_MAPPINGS.key?("labor_productivity_per_hour_ilo")
    assert IloMetricImporter::METRIC_MAPPINGS.key?("labor_productivity_per_worker_ilo")

    assert_equal :labor_productivity_per_hour, IloMetricImporter::METRIC_MAPPINGS["labor_productivity_per_hour_ilo"]
    assert_equal :labor_productivity_per_worker, IloMetricImporter::METRIC_MAPPINGS["labor_productivity_per_worker_ilo"]
  end

  # import_metric tests
  test "import_metric returns error counts when API fails" do
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 500, body: "", headers: {})

    result = IloMetricImporter.import_metric("labor_productivity_per_hour_ilo", :labor_productivity_per_hour)

    assert_equal 0, result[:imported]
    assert_equal 1, result[:errors]
    assert result[:error_message].present?
  end

  test "import_metric imports data successfully" do
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: build_valid_response.to_json, headers: {})

    result = IloMetricImporter.import_metric("labor_productivity_per_hour_ilo", :labor_productivity_per_hour)

    assert result[:imported] > 0
    assert_equal 0, result[:errors]

    # Verify data was saved
    metric = Metric.find_by(metric_name: "labor_productivity_per_hour_ilo", country: "germany", year: 2020)
    assert metric.present?
    assert_equal 75.5, metric.metric_value
  end

  test "import_metric handles duplicate records gracefully" do
    # First import
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: build_valid_response.to_json, headers: {})

    result1 = IloMetricImporter.import_metric("labor_productivity_per_hour_ilo", :labor_productivity_per_hour)

    # Second import should update existing records
    result2 = IloMetricImporter.import_metric("labor_productivity_per_hour_ilo", :labor_productivity_per_hour)

    assert_equal result1[:imported], result2[:imported]

    # Should still have same number of records
    count = Metric.where(metric_name: "labor_productivity_per_hour_ilo", country: "germany").count
    assert_equal 3, count # 3 years of data
  end

  # import_all tests
  test "import_all imports all metrics and comparison countries" do
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: build_valid_response.to_json, headers: {})

    results = IloMetricImporter.import_all

    assert results.key?("labor_productivity_per_hour_ilo")
    assert results.key?("labor_productivity_per_worker_ilo")
    assert results.key?(:comparison)
  end

  # import_comparison_countries tests
  test "import_comparison_countries imports data for usa, china, india" do
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: build_comparison_response.to_json, headers: {})

    result = IloMetricImporter.import_comparison_countries

    assert result[:imported] > 0
    assert_equal 0, result[:errors]

    # Verify comparison country data was saved
    usa_metric = Metric.find_by(metric_name: "labor_productivity_per_hour_ilo", country: "usa", year: 2020)
    assert usa_metric.present?
  end

  test "import_comparison_countries handles API errors gracefully" do
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 500, body: "", headers: {})

    result = IloMetricImporter.import_comparison_countries

    assert_equal 0, result[:imported]
    # Should not crash
  end

  # calculate_europe_aggregate tests
  test "calculate_europe_aggregate creates europe aggregate when enough countries" do
    # Create test data for 5+ countries
    countries = %w[germany france italy spain netherlands poland]
    countries.each_with_index do |country, idx|
      Metric.create!(
        metric_name: "labor_productivity_per_hour_ilo",
        country: country,
        year: 2020,
        metric_value: 70.0 + idx,
        unit: "2021 PPP $ per hour",
        source: "ILO"
      )
    end

    IloMetricImporter.calculate_europe_aggregate(
      metric_name: "labor_productivity_per_hour_ilo",
      start_year: 2020,
      end_year: 2020
    )

    europe_metric = Metric.find_by(
      metric_name: "labor_productivity_per_hour_ilo",
      country: "europe",
      year: 2020
    )

    assert europe_metric.present?
    assert_in_delta 72.5, europe_metric.metric_value, 0.1 # Average of 70-75
    assert_includes europe_metric.description, "6 countries"
  end

  test "calculate_europe_aggregate skips years with fewer than 5 countries" do
    # Create data for only 3 countries
    %w[germany france italy].each_with_index do |country, idx|
      Metric.create!(
        metric_name: "labor_productivity_per_hour_ilo",
        country: country,
        year: 2020,
        metric_value: 70.0 + idx,
        unit: "2021 PPP $ per hour",
        source: "ILO"
      )
    end

    IloMetricImporter.calculate_europe_aggregate(
      metric_name: "labor_productivity_per_hour_ilo",
      start_year: 2020,
      end_year: 2020
    )

    europe_metric = Metric.find_by(
      metric_name: "labor_productivity_per_hour_ilo",
      country: "europe",
      year: 2020
    )

    assert_nil europe_metric
  end

  test "calculate_europe_aggregate excludes comparison countries from calculation" do
    # Create data including comparison countries
    european = %w[germany france italy spain netherlands poland]
    comparison = %w[usa china india]

    european.each_with_index do |country, idx|
      Metric.create!(
        metric_name: "labor_productivity_per_hour_ilo",
        country: country,
        year: 2020,
        metric_value: 70.0,
        unit: "2021 PPP $ per hour",
        source: "ILO"
      )
    end

    comparison.each do |country|
      Metric.create!(
        metric_name: "labor_productivity_per_hour_ilo",
        country: country,
        year: 2020,
        metric_value: 90.0, # Higher value that should be excluded
        unit: "2021 PPP $ per hour",
        source: "ILO"
      )
    end

    IloMetricImporter.calculate_europe_aggregate(
      metric_name: "labor_productivity_per_hour_ilo",
      start_year: 2020,
      end_year: 2020
    )

    europe_metric = Metric.find_by(
      metric_name: "labor_productivity_per_hour_ilo",
      country: "europe",
      year: 2020
    )

    # Should be 70.0 (average of european countries only), not influenced by 90.0
    assert_equal 70.0, europe_metric.metric_value
  end

  private

  def build_valid_response
    {
      "meta" => { "prepared" => "2024-01-01T00:00:00Z" },
      "data" => {
        "structure" => {
          "dimensions" => {
            "series" => [
              { "id" => "REF_AREA", "values" => [ { "id" => "DEU" }, { "id" => "FRA" } ] },
              { "id" => "FREQ", "values" => [ { "id" => "A" } ] },
              { "id" => "MEASURE", "values" => [ { "id" => "GDP_2HRW_NB" } ] }
            ],
            "observation" => [
              { "id" => "TIME_PERIOD", "values" => [ { "id" => "2020" }, { "id" => "2021" }, { "id" => "2022" } ] }
            ]
          }
        },
        "dataSets" => [ {
          "series" => {
            "0:0:0" => { "observations" => { "0" => [ 75.5 ], "1" => [ 76.2 ], "2" => [ 77.0 ] } },
            "1:0:0" => { "observations" => { "0" => [ 70.0 ], "1" => [ 71.0 ], "2" => [ 72.0 ] } }
          }
        } ]
      }
    }
  end

  def build_comparison_response
    {
      "meta" => { "prepared" => "2024-01-01T00:00:00Z" },
      "data" => {
        "structure" => {
          "dimensions" => {
            "series" => [
              { "id" => "REF_AREA", "values" => [ { "id" => "USA" }, { "id" => "CHN" }, { "id" => "IND" } ] },
              { "id" => "FREQ", "values" => [ { "id" => "A" } ] },
              { "id" => "MEASURE", "values" => [ { "id" => "GDP_2HRW_NB" } ] }
            ],
            "observation" => [
              { "id" => "TIME_PERIOD", "values" => [ { "id" => "2020" }, { "id" => "2021" } ] }
            ]
          }
        },
        "dataSets" => [ {
          "series" => {
            "0:0:0" => { "observations" => { "0" => [ 80.0 ], "1" => [ 82.0 ] } },
            "1:0:0" => { "observations" => { "0" => [ 20.0 ], "1" => [ 22.0 ] } },
            "2:0:0" => { "observations" => { "0" => [ 15.0 ], "1" => [ 16.0 ] } }
          }
        } ]
      }
    }
  end
end
