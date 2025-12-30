require "test_helper"
require "webmock/minitest"

class OurWorldInDataServiceTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  teardown do
    WebMock.allow_net_connect!
  end

  # COUNTRIES constant tests
  test "COUNTRIES contains all EU-27 member states" do
    eu_countries = %w[germany france italy spain netherlands poland sweden denmark finland austria belgium czechia estonia greece hungary ireland latvia lithuania luxembourg malta portugal slovakia slovenia bulgaria croatia romania cyprus]

    eu_countries.each do |country|
      assert OurWorldInDataService::COUNTRIES.key?(country), "Missing EU country: #{country}"
    end
  end

  test "COUNTRIES contains comparison countries" do
    assert_equal "United States", OurWorldInDataService::COUNTRIES["usa"]
    assert_equal "India", OurWorldInDataService::COUNTRIES["india"]
    assert_equal "China", OurWorldInDataService::COUNTRIES["china"]
  end

  test "COUNTRIES contains transcontinental countries" do
    assert_equal "Russia", OurWorldInDataService::COUNTRIES["russia"]
    assert_equal "Turkey", OurWorldInDataService::COUNTRIES["turkey"]
  end

  # fetch_chart_data tests
  test "fetch_chart_data returns error when HTTP request fails" do
    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_return(status: 500, body: "", headers: {})

    result = OurWorldInDataService.fetch_chart_data("test-chart")

    assert result[:error].present?
    assert_includes result[:error], "500"
  end

  test "fetch_chart_data returns error when exception occurs" do
    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_raise(StandardError.new("Connection error"))

    result = OurWorldInDataService.fetch_chart_data("test-chart")

    assert result[:error].present?
    assert_includes result[:error], "Connection error"
  end

  test "fetch_chart_data parses CSV and returns structured data" do
    csv_data = <<~CSV
      Entity,Code,Year,Value
      Germany,DEU,2020,50000
      Germany,DEU,2021,51000
      France,FRA,2020,48000
      France,FRA,2021,49000
      United States,USA,2020,65000
      United States,USA,2021,67000
    CSV

    metadata_json = {
      "columns" => {
        "Value" => {
          "citationShort" => "World Bank",
          "descriptionShort" => "Test description",
          "unit" => "USD"
        }
      },
      "chart" => {
        "title" => "Test Chart"
      }
    }.to_json

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_return(status: 200, body: csv_data, headers: { "Content-Type" => "text/csv" })

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.metadata.json")
      .to_return(status: 200, body: metadata_json, headers: { "Content-Type" => "application/json" })

    result = OurWorldInDataService.fetch_chart_data("test-chart", start_year: 2020, end_year: 2021)

    assert_nil result[:error]
    assert result[:countries].present?
    assert_equal [ 2020, 2021 ], result[:years]
    assert_equal 50000.0, result[:countries]["germany"][:data][2020]
    assert_equal 65000.0, result[:countries]["usa"][:data][2020]
    assert_equal "World Bank", result[:metadata][:source]
    assert_equal "Test Chart", result[:metadata][:title]
  end

  test "fetch_chart_data handles empty CSV data" do
    csv_data = <<~CSV
      Entity,Code,Year,Value
    CSV

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_return(status: 200, body: csv_data, headers: {})

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.metadata.json")
      .to_return(status: 200, body: "{}", headers: {})

    result = OurWorldInDataService.fetch_chart_data("test-chart")

    assert result[:error].present?
    assert_includes result[:error], "No data"
  end

  test "fetch_chart_data filters by year range" do
    csv_data = <<~CSV
      Entity,Code,Year,Value
      Germany,DEU,1999,45000
      Germany,DEU,2020,50000
      Germany,DEU,2025,55000
    CSV

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_return(status: 200, body: csv_data, headers: {})

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.metadata.json")
      .to_return(status: 200, body: "{}", headers: {})

    result = OurWorldInDataService.fetch_chart_data("test-chart", start_year: 2000, end_year: 2024)

    assert_nil result[:error]
    assert_equal [ 2020 ], result[:years]
    assert_nil result[:countries]["germany"][:data][1999]
    assert_nil result[:countries]["germany"][:data][2025]
    assert_equal 50000.0, result[:countries]["germany"][:data][2020]
  end

  test "fetch_chart_data handles metadata request failure gracefully" do
    csv_data = <<~CSV
      Entity,Code,Year,Value
      Germany,DEU,2020,50000
    CSV

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_return(status: 200, body: csv_data, headers: {})

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.metadata.json")
      .to_return(status: 404, body: "", headers: {})

    result = OurWorldInDataService.fetch_chart_data("test-chart", start_year: 2020, end_year: 2024)

    # Should still succeed with default metadata
    assert_nil result[:error]
    assert result[:countries]["germany"][:data][2020].present?
  end

  # fetch_gdp_per_capita_ppp backward compatibility test
  test "fetch_gdp_per_capita_ppp calls fetch_chart_data with correct parameters" do
    csv_data = <<~CSV
      Entity,Code,Year,Value
      Germany,DEU,2020,50000
    CSV

    stub_request(:get, "https://ourworldindata.org/grapher/gdp-per-capita-worldbank.csv")
      .to_return(status: 200, body: csv_data, headers: {})

    stub_request(:get, "https://ourworldindata.org/grapher/gdp-per-capita-worldbank.metadata.json")
      .to_return(status: 200, body: "{}", headers: {})

    result = OurWorldInDataService.fetch_gdp_per_capita_ppp(start_year: 2000, end_year: 2024)

    assert_nil result[:error]
    assert result[:countries].present?
  end

  # Test countries that should be ignored
  test "fetch_chart_data ignores entities not in COUNTRIES map" do
    csv_data = <<~CSV
      Entity,Code,Year,Value
      Germany,DEU,2020,50000
      World,OWID_WRL,2020,40000
      Unknown Entity,UNK,2020,30000
    CSV

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_return(status: 200, body: csv_data, headers: {})

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.metadata.json")
      .to_return(status: 200, body: "{}", headers: {})

    result = OurWorldInDataService.fetch_chart_data("test-chart", start_year: 2020, end_year: 2024)

    assert_nil result[:error]
    assert_equal 50000.0, result[:countries]["germany"][:data][2020]
    # World and Unknown Entity should not be present
    refute result[:countries].key?("world")
    refute result[:countries].key?("unknown_entity")
  end

  test "fetch_chart_data handles CSV parsing errors" do
    # Invalid CSV that will fail to parse
    csv_data = "Not,Valid,CSV\n\"unclosed quote"

    stub_request(:get, "https://ourworldindata.org/grapher/test-chart.csv")
      .to_return(status: 200, body: csv_data, headers: {})

    result = OurWorldInDataService.fetch_chart_data("test-chart")

    assert result[:error].present?
  end
end
