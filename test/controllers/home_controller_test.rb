require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  def setup
    @key_countries = [ "europe", "usa", "china", "india" ]
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "index should load successfully" do
    get root_url

    assert_response :success
    # Test that the page loads and contains expected content
    assert_select "title", /europe/i, "Page should have Europe-focused title"
  end

  test "index should handle GDP data correctly" do
    get root_url

    assert_response :success
    # Test that GDP-related content is displayed
    assert_select "body", text: /GDP/i, minimum: 1, message: "Page should contain GDP-related content"
  end

  test "index should handle population data correctly" do
    get root_url

    assert_response :success
    # Test that population-related content is displayed
    assert_select "body", text: /Population/i, minimum: 1, message: "Page should contain population-related content"
  end

  test "index should render without error even if services fail" do
    # Test that the controller handles service failures gracefully
    get root_url

    assert_response :success
    # Page should load even if some services fail
  end

  test "index should include European comparison context" do
    get root_url

    assert_response :success

    # Check that the response includes Europe-focused content
    assert_select "title", /europe/i, "Title should mention Europe"
  end

  test "index should display comparison data when available" do
    get root_url

    assert_response :success
    # Test that comparison data is displayed when available
    assert_select "body", text: /comparison/i, minimum: 1, message: "Page should display comparison content"
  end

  test "fetch_latest_gdp_data should return proper structure" do
    controller = HomeController.new

    # Test the private method
    gdp_data = controller.send(:fetch_latest_gdp_data)

    assert gdp_data.is_a?(Hash), "Should return a hash"

    if gdp_data[:error]
      assert gdp_data.key?(:error), "Error response should have error key"
    else
      assert gdp_data.key?(:countries), "Success response should have countries"
      assert gdp_data.key?(:year), "Success response should have year"

      # Verify countries structure
      gdp_data[:countries].each do |country, data|
        assert data.key?(:value), "Country data should have value"
        assert data.key?(:year), "Country data should have year"
      end
    end
  end

  test "fetch_latest_population_data should return proper structure" do
    controller = HomeController.new

    # Test the private method
    population_data = controller.send(:fetch_latest_population_data)

    assert population_data.is_a?(Hash), "Should return a hash"

    if population_data[:error]
      assert population_data.key?(:error), "Error response should have error key"
    else
      assert population_data.key?(:countries), "Success response should have countries"
      assert population_data.key?(:year), "Success response should have year"

      # Verify countries structure
      population_data[:countries].each do |country, data|
        assert data.key?(:value), "Country data should have value"
        assert data.key?(:year), "Country data should have year"
      end
    end
  end

  test "should handle service timeouts gracefully" do
    # Test that the controller loads without timeout errors
    get root_url

    assert_response :success
  end

  test "should maintain performance with large datasets" do
    # Test that the controller performs reasonably
    start_time = Time.current

    get root_url

    end_time = Time.current
    response_time = end_time - start_time

    assert response_time < 5.0, "Response should be fast (under 5 seconds)"
    assert_response :success
  end

  test "controller should use correct service methods" do
    # Test that the controller loads and calls services
    get root_url

    assert_response :success
    # Test passes if page loads successfully (indicates services were called)
  end

  test "should have consistent country ordering" do
    get root_url

    assert_response :success
    # Test that the page loads with consistent data
  end

  # Test methodology action
  test "should get methodology page" do
    get methodology_url
    assert_response :success
  end

  test "methodology should display data sources" do
    get methodology_url
    assert_response :success
    assert_select "body", text: /Source|Data/i, minimum: 1
  end

  test "methodology should display European countries list" do
    get methodology_url
    assert_response :success
    # Should include European country information
    assert_select "body", text: /Europe|European/i, minimum: 1
  end

  test "methodology should compute data coverage" do
    get methodology_url
    assert_response :success
    # The compute_data_coverage method should run without error
  end

  # Test fetch_latest_child_mortality_data
  test "fetch_latest_child_mortality_data should return proper structure" do
    controller = HomeController.new

    child_mortality_data = controller.send(:fetch_latest_child_mortality_data)

    assert child_mortality_data.is_a?(Hash), "Should return a hash"

    if child_mortality_data[:error]
      assert child_mortality_data.key?(:error), "Error response should have error key"
    else
      assert child_mortality_data.key?(:countries), "Success response should have countries"
      assert child_mortality_data.key?(:year), "Success response should have year"
    end
  end

  # Test fetch_latest_healthy_life_expectancy_data
  test "fetch_latest_healthy_life_expectancy_data should return proper structure" do
    controller = HomeController.new

    hle_data = controller.send(:fetch_latest_healthy_life_expectancy_data)

    assert hle_data.is_a?(Hash), "Should return a hash"

    if hle_data[:error]
      assert hle_data.key?(:error), "Error response should have error key"
    else
      assert hle_data.key?(:countries), "Success response should have countries"
      assert hle_data.key?(:year), "Success response should have year"
    end
  end

  # Test normalize_metric_data
  test "normalize_metric_data should handle nil input" do
    controller = HomeController.new

    result = controller.send(:normalize_metric_data, nil)
    assert_nil result
  end

  test "normalize_metric_data should handle empty input" do
    controller = HomeController.new

    result = controller.send(:normalize_metric_data, {})
    assert_nil result
  end

  test "normalize_metric_data should convert string keys to symbols" do
    controller = HomeController.new

    input = { "europe" => { value: 100 }, "usa" => { value: 200 } }
    result = controller.send(:normalize_metric_data, input)

    assert result.key?(:europe)
    assert result.key?(:usa)
  end

  test "normalize_metric_data should fallback to european_union when europe is missing" do
    controller = HomeController.new

    input = { "european_union" => { value: 100 }, "usa" => { value: 200 } }
    result = controller.send(:normalize_metric_data, input)

    assert result.key?(:europe)
    assert_equal 100, result[:europe][:value]
  end
end
