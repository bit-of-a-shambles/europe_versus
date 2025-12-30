require "test_helper"
require "webmock/minitest"

class IloDataServiceTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  teardown do
    WebMock.allow_net_connect!
  end

  # Constants tests
  test "DATAFLOWS contains labor productivity indicators" do
    assert IloDataService::DATAFLOWS.key?(:labor_productivity_per_hour)
    assert IloDataService::DATAFLOWS.key?(:labor_productivity_per_worker)

    assert_equal "GDP_2HRW_NB", IloDataService::DATAFLOWS[:labor_productivity_per_hour][:measure]
    assert_equal "GDP_205U_NB", IloDataService::DATAFLOWS[:labor_productivity_per_worker][:measure]
  end

  test "COUNTRY_CODES contains European countries" do
    assert_equal "DEU", IloDataService::COUNTRY_CODES["germany"]
    assert_equal "FRA", IloDataService::COUNTRY_CODES["france"]
    assert_equal "GBR", IloDataService::COUNTRY_CODES["united_kingdom"]
  end

  test "COUNTRY_CODES contains comparison countries" do
    assert_equal "USA", IloDataService::COUNTRY_CODES["usa"]
    assert_equal "IND", IloDataService::COUNTRY_CODES["india"]
    assert_equal "CHN", IloDataService::COUNTRY_CODES["china"]
  end

  test "CODE_TO_COUNTRY is inverse of COUNTRY_CODES" do
    assert_equal "germany", IloDataService::CODE_TO_COUNTRY["DEU"]
    assert_equal "usa", IloDataService::CODE_TO_COUNTRY["USA"]
  end

  # fetch_indicator tests
  test "fetch_indicator returns error for unknown indicator" do
    result = IloDataService.fetch_indicator(:unknown_indicator)

    assert result[:error].present?
    assert_includes result[:error], "Unknown indicator"
  end

  test "fetch_indicator returns error when API request fails" do
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 500, body: "", headers: {})

    result = IloDataService.fetch_indicator(:labor_productivity_per_hour, countries: [ "germany" ])

    assert result[:error].present?
  end

  test "fetch_indicator returns error when exception occurs" do
    stub_request(:get, /sdmx\.ilo\.org/)
      .to_raise(StandardError.new("Connection failed"))

    result = IloDataService.fetch_indicator(:labor_productivity_per_hour, countries: [ "germany" ])

    assert result[:error].present?
    assert_includes result[:error], "Connection failed"
  end

  test "fetch_indicator parses valid SDMX JSON response" do
    response_body = build_valid_ilo_response

    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = IloDataService.fetch_indicator(:labor_productivity_per_hour, countries: [ "germany" ])

    assert_nil result[:error]
    assert result[:data].present?
    assert result[:metadata].present?
    assert_equal "ILO - Modelled Estimates", result[:metadata][:source]
  end

  test "fetch_indicator returns error when no data structure in response" do
    response_body = { "data" => {} }

    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: response_body.to_json, headers: {})

    result = IloDataService.fetch_indicator(:labor_productivity_per_hour, countries: [ "germany" ])

    assert result[:error].present?
    assert_includes result[:error], "No data structure"
  end

  test "fetch_indicator returns error when no datasets in response" do
    response_body = {
      "data" => {
        "structure" => { "dimensions" => {} },
        "dataSets" => []
      }
    }

    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: response_body.to_json, headers: {})

    result = IloDataService.fetch_indicator(:labor_productivity_per_hour, countries: [ "germany" ])

    assert result[:error].present?
    assert_includes result[:error], "No datasets"
  end

  test "fetch_indicator returns error when missing dimension information" do
    response_body = {
      "data" => {
        "structure" => {
          "dimensions" => {
            "series" => [],
            "observation" => []
          }
        },
        "dataSets" => [ {} ]
      }
    }

    stub_request(:get, /sdmx\.ilo\.org/)
      .to_return(status: 200, body: response_body.to_json, headers: {})

    result = IloDataService.fetch_indicator(:labor_productivity_per_hour, countries: [ "germany" ])

    assert result[:error].present?
    assert_includes result[:error], "Missing dimension"
  end

  # Convenience method tests
  test "fetch_labor_productivity_per_hour calls fetch_indicator with correct params" do
    stub_request(:get, /sdmx\.ilo\.org.*GDP_2HRW_NB/)
      .to_return(status: 200, body: build_valid_ilo_response.to_json, headers: {})

    result = IloDataService.fetch_labor_productivity_per_hour(countries: [ "germany" ])

    assert_nil result[:error]
    assert_equal :labor_productivity_per_hour, result[:metadata][:indicator]
  end

  test "fetch_labor_productivity_per_worker calls fetch_indicator with correct params" do
    stub_request(:get, /sdmx\.ilo\.org.*GDP_205U_NB/)
      .to_return(status: 200, body: build_valid_ilo_response(:labor_productivity_per_worker).to_json, headers: {})

    result = IloDataService.fetch_labor_productivity_per_worker(countries: [ "germany" ])

    assert_nil result[:error]
    assert_equal :labor_productivity_per_worker, result[:metadata][:indicator]
  end

  test "fetch_indicator with no countries fetches all available" do
    stub_request(:get, /sdmx\.ilo\.org.*\.A\./)
      .to_return(status: 200, body: build_valid_ilo_response.to_json, headers: {})

    result = IloDataService.fetch_indicator(:labor_productivity_per_hour)

    assert_nil result[:error]
  end

  private

  def build_valid_ilo_response(indicator = :labor_productivity_per_hour)
    {
      "meta" => {
        "prepared" => "2024-01-01T00:00:00Z"
      },
      "data" => {
        "structure" => {
          "dimensions" => {
            "series" => [
              {
                "id" => "REF_AREA",
                "values" => [
                  { "id" => "DEU", "name" => "Germany" },
                  { "id" => "FRA", "name" => "France" }
                ]
              },
              {
                "id" => "FREQ",
                "values" => [ { "id" => "A", "name" => "Annual" } ]
              },
              {
                "id" => "MEASURE",
                "values" => [ { "id" => "GDP_2HRW_NB", "name" => "Output per hour" } ]
              }
            ],
            "observation" => [
              {
                "id" => "TIME_PERIOD",
                "values" => [
                  { "id" => "2020" },
                  { "id" => "2021" },
                  { "id" => "2022" }
                ]
              }
            ]
          }
        },
        "dataSets" => [
          {
            "series" => {
              "0:0:0" => {
                "observations" => {
                  "0" => [ 75.5 ],
                  "1" => [ 76.2 ],
                  "2" => [ 77.0 ]
                }
              },
              "1:0:0" => {
                "observations" => {
                  "0" => [ 70.0 ],
                  "1" => [ 71.0 ],
                  "2" => [ 72.0 ]
                }
              }
            }
          }
        ]
      }
    }
  end
end
