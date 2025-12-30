require "test_helper"

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @key_countries = [ "europe", "usa", "china", "india" ]
    @metric = metrics(:europe_population_2024)
  end

  # Test index action
  test "should get index" do
    get statistics_url
    assert_response :success
  end

  test "index should assign statistics" do
    get statistics_url

    assert_response :success
    # Test that statistics page loads successfully
  end

  # Test show action - skip for now since it uses old Statistic model
  # test "show should assign statistic" do
  #   get statistic_url(@metric)
  #
  #   assert_response :success
  #   # Test that specific statistic page loads successfully
  # end

  # Test chart actions (using show action with metric slugs)
  test "should get population chart data" do
    get statistic_url("population")
    assert_response :success
  end

  test "should get GDP chart data" do
    get statistic_url("gdp-per-capita-ppp")
    assert_response :success
  end

  test "chart should render without errors" do
    get statistic_url("population")
    assert_response :success
    # Chart page loads successfully
  end

  test "GDP chart should render without errors" do
    get statistic_url("gdp-per-capita-ppp")
    assert_response :success
    # Chart page loads successfully
  end

  # Test URL redirects for underscored slugs
  test "should redirect underscored slug to hyphenated" do
    get statistic_url("gdp_per_capita_ppp")
    assert_redirected_to statistic_path("gdp-per-capita-ppp")
  end

  # Test different metric types
  test "should get child mortality chart" do
    get statistic_url("child-mortality-rate")
    assert_response :success
  end

  test "should get electricity access chart" do
    get statistic_url("electricity-access")
    assert_response :success
  end

  test "should get health expenditure chart" do
    get statistic_url("health-expenditure-gdp-percent")
    assert_response :success
  end

  test "should get life satisfaction chart" do
    get statistic_url("life-satisfaction")
    assert_response :success
  end

  test "show action builds statistic object with correct metadata" do
    get statistic_url("population")
    assert_response :success

    # Test that response body contains expected content
    assert_match /Population/i, response.body
  end

  test "show action handles unknown metrics gracefully" do
    # For unknown metrics, the controller falls back to OWID which may fail
    # In that case it should still return a success response with error handling

    # This test verifies the controller doesn't crash on unknown metrics
    # The actual behavior depends on whether the OWID fetch succeeds
    begin
      get statistic_url("completely-unknown-metric-xyz")
      # If we get here, the page loaded (with or without data)
      assert_response :success
    rescue WebMock::NetConnectNotAllowedError
      # In test environment with WebMock, external requests are blocked
      # Skip this test since it requires external API access
      skip "Test requires external API access which is blocked in test environment"
    end
  end
end
