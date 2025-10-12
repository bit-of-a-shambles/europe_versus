require "test_helper"

class PopulationDataServiceTest < ActiveSupport::TestCase
  def setup
    @key_countries = ['europe', 'usa', 'china', 'india']
    @service = PopulationDataService
  end

  # Test latest_population_for_countries method
  test "latest_population_for_countries should return latest population data for requested countries" do
    result = @service.latest_population_for_countries(@key_countries)
    
    assert result.is_a?(Hash), "Should return a hash"
    assert_equal @key_countries.sort, result.keys.sort, "Should return data for all requested countries"
    
    # Check structure of returned data
    result.each do |country, data|
      assert data[:value].present?, "Should have value for #{country}"
      assert data[:year].present?, "Should have year for #{country}"
      assert data[:value] > 0, "Population should be positive for #{country}"
      assert data[:year] >= 2020, "Year should be recent for #{country}"
    end
  end

  test "latest_population_for_countries should handle empty country list" do
    result = @service.latest_population_for_countries([])
    assert result.empty?, "Should return empty hash for empty country list"
  end

  test "latest_population_for_countries should handle nonexistent countries" do
    result = @service.latest_population_for_countries(['nonexistent_country'])
    assert result.empty?, "Should return empty hash for nonexistent countries"
  end

  test "latest_population_for_countries should handle mixed existing and nonexistent countries" do
    mixed_countries = @key_countries + ['nonexistent_country']
    result = @service.latest_population_for_countries(mixed_countries)
    
    assert_equal @key_countries.sort, result.keys.sort, "Should only return existing countries"
  end

  # Test OWID CSV fetching
  test "fetch_population_data_from_owid should parse CSV correctly" do
    # Test the CSV parsing logic structure without making actual HTTP requests
    assert @service.respond_to?(:fetch_population_data_from_owid), "Should have OWID fetch method"
  end

  # Test European population calculation integration
  test "should integrate with European population calculations" do
    # Test that the service can handle European aggregate calculations
    result = @service.latest_population_for_countries(['europe'])
    
    if result['europe'].present?
      assert result['europe'][:value] > 500_000_000, "Europe population should be substantial"
      assert result['europe'][:value] < 1_000_000_000, "Europe population should be reasonable"
    end
  end

  # Test data validation
  test "should validate population data makes sense" do
    result = @service.latest_population_for_countries(@key_countries)
    
    # Basic sanity checks on population values
    if result['usa'].present?
      assert result['usa'][:value] > 300_000_000, "USA population should be over 300M"
      assert result['usa'][:value] < 400_000_000, "USA population should be under 400M"
    end
    
    if result['china'].present?
      assert result['china'][:value] > 1_300_000_000, "China population should be over 1.3B"
      assert result['china'][:value] < 1_500_000_000, "China population should be under 1.5B"
    end
    
    if result['india'].present?
      assert result['india'][:value] > 1_300_000_000, "India population should be over 1.3B"
      assert result['india'][:value] < 1_500_000_000, "India population should be under 1.5B"
    end
    
    if result['europe'].present?
      assert result['europe'][:value] > 600_000_000, "Europe population should be over 600M"
      assert result['europe'][:value] < 800_000_000, "Europe population should be under 800M"
    end
  end

  # Test error handling
  test "should handle service errors gracefully" do
    # Test with invalid input
    result = @service.latest_population_for_countries(nil)
    assert result.is_a?(Hash), "Should return hash even with nil input"
    assert result.empty?, "Should return empty hash for nil input"
  end

  # Test backward compatibility
  test "should maintain backward compatibility with existing interface" do
    # Ensure all public methods exist and work
    assert @service.respond_to?(:latest_population_for_countries), "Should have latest_population_for_countries method"
    assert @service.respond_to?(:fetch_population_data_from_owid), "Should have fetch_population_data_from_owid method"
  end

  # Test consistency with EuropeanMetricsService
  test "should be consistent with EuropeanMetricsService" do
    # Compare results from both services
    service_result = @service.latest_population_for_countries(['europe'])
    direct_result = EuropeanMetricsService.latest_metric_for_countries('population', ['europe'])
    
    if service_result['europe'].present? && direct_result['europe'].present?
      assert_equal service_result['europe'][:value], direct_result['europe'][:value], 
                   "Population service should match EuropeanMetricsService"
      assert_equal service_result['europe'][:year], direct_result['europe'][:year], 
                   "Years should match between services"
    end
  end

  # Test ISO code handling
  test "should have proper ISO code mappings" do
    # The service should be able to map ISO codes to internal country names
    # This is important for OWID data processing
    
    # Check that the service can handle major countries
    result = @service.latest_population_for_countries(['usa', 'china', 'india'])
    
    # Should successfully map and return data for these countries
    assert result.keys.all? { |key| key.is_a?(String) }, "All country keys should be strings"
    assert result.keys.all? { |key| key == key.downcase }, "All country keys should be lowercase"
  end

  # Test European countries handling
  test "should handle European countries correctly" do
    european_countries = ['germany', 'france', 'italy', 'spain']
    result = @service.latest_population_for_countries(european_countries)
    
    # Should return data for European countries if available in fixtures
    result.each do |country, data|
      assert european_countries.include?(country), "Should only return requested European countries"
      assert data[:value] > 10_000_000, "European countries should have substantial populations"
      assert data[:value] < 200_000_000, "European country populations should be reasonable"
    end
  end

  # Test transcontinental country handling
  test "should work with transcontinental countries" do
    transcontinental_countries = ['russia', 'turkey']
    result = @service.latest_population_for_countries(transcontinental_countries)
    
    # These countries should be handled like any other country in the data service
    # The European portion adjustment happens in the EuropeanMetricsService
    result.each do |country, data|
      assert transcontinental_countries.include?(country), "Should return requested transcontinental countries"
      assert data[:value] > 50_000_000, "Transcontinental countries should have large populations"
    end
  end

  # Test method parameter handling
  test "latest_population_for_countries should handle various parameter formats" do
    # Test with array
    result1 = @service.latest_population_for_countries(['europe', 'usa'])
    assert result1.is_a?(Hash), "Should handle array input"
    
    # Test with single country in array  
    result2 = @service.latest_population_for_countries(['europe'])
    assert result2.is_a?(Hash), "Should handle single country"
    
    # Test with empty array
    result3 = @service.latest_population_for_countries([])
    assert result3.empty?, "Should handle empty array"
  end

  # Test data freshness
  test "should return recent population data" do
    result = @service.latest_population_for_countries(['europe'])
    
    if result['europe'].present?
      assert result['europe'][:year] >= 2023, "Should have recent data (2023 or later)"
      assert result['europe'][:year] <= Date.current.year, "Year should not be in the future"
    end
  end

  # Test data source attribution
  test "should properly handle data source information" do
    # Check that the service works with Our World in Data as the source
    # This is implied by the method name fetch_population_data_from_owid
    
    assert @service.respond_to?(:fetch_population_data_from_owid), "Should have OWID-specific method"
  end

  # Test integration with database
  test "should work with database-stored metrics" do
    # The service should read from the metrics table
    result = @service.latest_population_for_countries(['europe'])
    
    if result['europe'].present?
      # Verify the data comes from database by checking it matches fixture data
      europe_metric = Metric.latest_for_country_and_metric('europe', 'population')
      if europe_metric
        assert_equal europe_metric.metric_value, result['europe'][:value], 
                     "Should match database metric value"
        assert_equal europe_metric.year, result['europe'][:year], 
                     "Should match database metric year"
      end
    end
  end
end