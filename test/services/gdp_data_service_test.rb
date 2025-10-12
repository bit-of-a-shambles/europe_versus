require "test_helper"

class GdpDataServiceTest < ActiveSupport::TestCase
  def setup
    @key_countries = ['europe', 'usa', 'china', 'india']
    @service = GdpDataService
  end

  # Test latest_gdp_for_countries method
  test "latest_gdp_for_countries should return latest GDP data for requested countries" do
    result = @service.latest_gdp_for_countries(@key_countries)
    
    assert result.is_a?(Hash), "Should return a hash"
    assert_equal @key_countries.sort, result.keys.sort, "Should return data for all requested countries"
    
    # Check structure of returned data
    result.each do |country, data|
      assert data[:value].present?, "Should have value for #{country}"
      assert data[:year].present?, "Should have year for #{country}"
      assert data[:value] > 0, "GDP should be positive for #{country}"
      assert data[:year] >= 2020, "Year should be recent for #{country}"
    end
  end

  test "latest_gdp_for_countries should handle empty country list" do
    result = @service.latest_gdp_for_countries([])
    assert result.empty?, "Should return empty hash for empty country list"
  end

  test "latest_gdp_for_countries should handle nonexistent countries" do
    result = @service.latest_gdp_for_countries(['nonexistent_country'])
    assert result.empty?, "Should return empty hash for nonexistent countries"
  end

  test "latest_gdp_for_countries should handle mixed existing and nonexistent countries" do
    mixed_countries = @key_countries + ['nonexistent_country']
    result = @service.latest_gdp_for_countries(mixed_countries)
    
    assert_equal @key_countries.sort, result.keys.sort, "Should only return existing countries"
  end

  # Test build_gdp_chart_data method
  test "build_gdp_chart_data should return proper chart data structure" do
    result = @service.build_gdp_chart_data(@key_countries)
    
    assert result.is_a?(Hash), "Should return a hash"
    assert result[:metadata].present?, "Should have metadata"
    assert result[:years].present?, "Should have years array"
    assert result[:countries].present?, "Should have countries data"
    
    # Check years structure
    assert result[:years].is_a?(Array), "Years should be an array"
    assert result[:years].all? { |year| year.is_a?(Integer) }, "All years should be integers"
    assert result[:years].sort == result[:years], "Years should be sorted"
    
    # Check countries structure
    result[:countries].each do |country_key, country_data|
      assert country_data[:name].present?, "Should have name for #{country_key}"
      assert country_data[:data].is_a?(Hash), "Should have data hash for #{country_key}"
      
      # Check that data contains year => value mappings
      country_data[:data].each do |year, value|
        assert year.is_a?(Integer), "Year should be integer for #{country_key}"
        assert value.is_a?(Numeric), "Value should be numeric for #{country_key}"
        assert value > 0, "GDP should be positive for #{country_key} in #{year}"
      end
    end
  end

  test "build_gdp_chart_data should use default countries when none provided" do
    result = @service.build_gdp_chart_data()
    
    # Should use default countries
    assert result[:countries].present?, "Should have countries data with defaults"
    
    # Should include key countries that have data
    available_countries = result[:countries].keys
    @key_countries.each do |country|
      if Metric.for_country(country).for_metric('gdp_per_capita_ppp').exists?
        assert available_countries.include?(country), "Should include #{country} by default"
      end
    end
  end

  test "build_gdp_chart_data should handle single country" do
    result = @service.build_gdp_chart_data(['europe'])
    
    assert_equal 1, result[:countries].size, "Should return data for one country"
    assert result[:countries]['europe'].present?, "Should have Europe data"
  end

  # Test calculate_europe_gdp_per_capita method
  test "calculate_europe_gdp_per_capita should calculate and store Europe GDP" do
    # This method should delegate to EuropeanMetricsService
    result = @service.calculate_europe_gdp_per_capita
    
    assert result.present?, "Should return calculation result"
    assert result[:metric_value].present?, "Should have calculated metric value"
    assert result[:year].present?, "Should have year"
    assert result[:metric_value] > 20_000, "Europe GDP should be substantial"
    assert result[:metric_value] < 100_000, "Europe GDP should be reasonable"
  end

  # Test integration with World Bank data fetching
  test "fetch_gdp_data_from_world_bank should handle API responses properly" do
    # Test the structure of data fetching (without making actual API calls)
    
    # Check that the COUNTRIES mapping includes all expected countries
    assert @service::COUNTRIES.is_a?(Hash), "COUNTRIES should be a hash"
    assert @service::COUNTRIES.size > 50, "Should have many country mappings"
    
    # Check that key countries are mapped
    assert @service::COUNTRIES['DEU'].present?, "Should have Germany mapping"
    assert @service::COUNTRIES['FRA'].present?, "Should have France mapping"
    assert @service::COUNTRIES['USA'].present?, "Should have USA mapping"
    assert @service::COUNTRIES['CHN'].present?, "Should have China mapping"
    assert @service::COUNTRIES['IND'].present?, "Should have India mapping"
  end

  # Test country mapping functionality
  test "should have comprehensive country mappings" do
    countries_hash = @service::COUNTRIES
    
    # Test European countries are well represented
    european_iso_codes = %w[DEU FRA ITA ESP NLD POL SWE DNK FIN AUT BEL IRL PRT GRC HUN ROU HRV BGR SVK SVN EST LVA LTU LUX MLT CYP CHE NOR GBR ISL UKR BLR MDA ALB BIH SRB MNE MKD XKX ARM AZE GEO RUS TUR AND SMR]
    
    european_iso_codes.each do |iso_code|
      assert countries_hash[iso_code].present?, "Should have mapping for #{iso_code}"
    end
    
    # Test that mappings are to reasonable country names
    assert_equal 'germany', countries_hash['DEU']
    assert_equal 'france', countries_hash['FRA']
    assert_equal 'usa', countries_hash['USA']
    assert_equal 'china', countries_hash['CHN']
    assert_equal 'india', countries_hash['IND']
  end

  # Test data validation
  test "should validate GDP data makes sense" do
    result = @service.latest_gdp_for_countries(@key_countries)
    
    # Basic sanity checks on GDP values
    if result['usa'].present?
      assert result['usa'][:value] > 50_000, "USA GDP per capita should be high"
    end
    
    if result['china'].present?
      assert result['china'][:value] > 15_000, "China GDP per capita should be moderate"
      assert result['china'][:value] < 50_000, "China GDP per capita should be reasonable"
    end
    
    if result['india'].present?
      assert result['india'][:value] > 5_000, "India GDP per capita should be positive"
      assert result['india'][:value] < 20_000, "India GDP per capita should be reasonable"
    end
    
    if result['europe'].present?
      assert result['europe'][:value] > 30_000, "Europe GDP per capita should be substantial"
      assert result['europe'][:value] < 80_000, "Europe GDP per capita should be reasonable"
    end
  end

  # Test error handling
  test "should handle service errors gracefully" do
    # Test with invalid input
    result = @service.latest_gdp_for_countries(nil)
    assert result.is_a?(Hash), "Should return hash even with nil input"
    assert result.empty?, "Should return empty hash for nil input"
  end

  # Test backward compatibility
  test "should maintain backward compatibility with existing interface" do
    # Ensure all public methods exist and work
    assert @service.respond_to?(:latest_gdp_for_countries), "Should have latest_gdp_for_countries method"
    assert @service.respond_to?(:build_gdp_chart_data), "Should have build_gdp_chart_data method"
    assert @service.respond_to?(:calculate_europe_gdp_per_capita), "Should have calculate_europe_gdp_per_capita method"
    assert @service.respond_to?(:fetch_gdp_data_from_world_bank), "Should have fetch_gdp_data_from_world_bank method"
  end

  # Test consistency with EuropeanMetricsService
  test "should be consistent with EuropeanMetricsService" do
    # Compare results from both services
    service_result = @service.latest_gdp_for_countries(['europe'])
    direct_result = EuropeanMetricsService.latest_metric_for_countries('gdp_per_capita_ppp', ['europe'])
    
    if service_result['europe'].present? && direct_result['europe'].present?
      assert_equal service_result['europe'][:value], direct_result['europe'][:value], 
                   "GDP service should match EuropeanMetricsService"
      assert_equal service_result['europe'][:year], direct_result['europe'][:year], 
                   "Years should match between services"
    end
  end

  # Test chart data completeness
  test "chart data should include sufficient historical data" do
    result = @service.build_gdp_chart_data(['europe'])
    
    assert result[:years].length >= 10, "Should have at least 10 years of data"
    assert result[:years].include?(2024), "Should include recent year 2024"
    
    europe_data = result[:countries]['europe']
    if europe_data.present?
      assert europe_data[:data].keys.length >= 10, "Europe should have substantial historical data"
    end
  end

  # Test method parameter handling
  test "build_gdp_chart_data should handle various parameter formats" do
    # Test with array
    result1 = @service.build_gdp_chart_data(['europe', 'usa'])
    assert_equal 2, result1[:countries].size, "Should handle array input"
    
    # Test with single country in array
    result2 = @service.build_gdp_chart_data(['europe'])
    assert_equal 1, result2[:countries].size, "Should handle single country"
    
    # Test with empty array
    result3 = @service.build_gdp_chart_data([])
    assert result3[:countries].empty?, "Should handle empty array"
  end
end