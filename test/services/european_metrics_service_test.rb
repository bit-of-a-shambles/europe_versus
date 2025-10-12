require "test_helper"

class EuropeanMetricsServiceTest < ActiveSupport::TestCase
  def setup
    # Ensure we have test data
    @key_countries = ['europe', 'usa', 'china', 'india']
    @european_countries = ['germany', 'france', 'russia', 'turkey']
  end

  # Test main calculate_europe_aggregate method
  test "calculate_europe_aggregate should work for population with simple_sum method" do
    result = EuropeanMetricsService.calculate_europe_aggregate('population', method: :simple_sum, min_countries: 1)
    
    assert result.present?, "Should return a result hash"
    assert result[:metric_value].present?, "Should have metric_value"
    assert result[:year].present?, "Should have year"
    assert result[:unit] == 'people', "Should have correct unit"
    assert result[:metric_value] > 0, "Population should be positive"
  end

  test "calculate_europe_aggregate should work for GDP with population_weighted method" do
    result = EuropeanMetricsService.calculate_europe_aggregate('gdp_per_capita_ppp', method: :population_weighted)
    
    assert result.present?, "Should return a result hash"
    assert result[:metric_value].present?, "Should have metric_value"
    assert result[:year].present?, "Should have year"
    assert result[:unit] == 'international_dollars', "Should have correct unit"
    assert result[:metric_value] > 0, "GDP should be positive"
  end

  test "calculate_europe_aggregate should auto-detect calculation method" do
    # Test auto-detection for population (should use simple_sum)
    pop_result = EuropeanMetricsService.calculate_europe_aggregate('population')
    assert pop_result.present?
    
    # Test auto-detection for GDP (should use population_weighted)
    gdp_result = EuropeanMetricsService.calculate_europe_aggregate('gdp_per_capita_ppp')
    assert gdp_result.present?
  end

  test "calculate_europe_aggregate should handle life_expectancy metric" do
    # Life expectancy should use population_weighted method
    method = EuropeanMetricsService.detect_calculation_method('life_expectancy')
    assert_equal :population_weighted, method
  end

  # Test private helper methods through public interface
  test "countries_with_metric_data should return countries with data" do
    countries = EuropeanMetricsService.countries_with_metric_data('population')
    
    assert countries.include?('germany'), "Should include Germany for population"
    assert countries.include?('france'), "Should include France for population"
    assert countries.include?('russia'), "Should include Russia for population"
    assert countries.include?('turkey'), "Should include Turkey for population"
  end

  test "detect_calculation_method should return correct methods" do
    assert_equal :simple_sum, EuropeanMetricsService.detect_calculation_method('population')
    assert_equal :population_weighted, EuropeanMetricsService.detect_calculation_method('gdp_per_capita_ppp')
    assert_equal :population_weighted, EuropeanMetricsService.detect_calculation_method('life_expectancy')
    assert_equal :population_weighted_rate, EuropeanMetricsService.detect_calculation_method('birth_rate')
    assert_equal :population_weighted, EuropeanMetricsService.detect_calculation_method('unknown_metric')
  end

  # Test latest_metric_for_countries method
  test "latest_metric_for_countries should return latest data for requested countries" do
    result = EuropeanMetricsService.latest_metric_for_countries('population', @key_countries)
    
    assert result.is_a?(Hash), "Should return a hash"
    assert_equal @key_countries.sort, result.keys.sort, "Should return data for all requested countries"
    
    # Check structure of returned data
    result.each do |country, data|
      assert data[:value].present?, "Should have value for #{country}"
      assert data[:year].present?, "Should have year for #{country}"
      assert data[:value] > 0, "Value should be positive for #{country}"
    end
  end

  test "latest_metric_for_countries should handle missing countries gracefully" do
    countries_with_missing = @key_countries + ['nonexistent_country']
    result = EuropeanMetricsService.latest_metric_for_countries('population', countries_with_missing)
    
    # Should only return countries that exist
    assert_equal @key_countries.sort, result.keys.sort
  end

  # Test build_metric_chart_data method
  test "build_metric_chart_data should return proper chart data structure" do
    result = EuropeanMetricsService.build_metric_chart_data('population', countries: @key_countries, start_year: 2023, end_year: 2024)
    
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
    end
  end

  test "build_metric_chart_data should respect date range filters" do
    result = EuropeanMetricsService.build_metric_chart_data('population', 
      countries: ['europe'], 
      start_year: 2024, 
      end_year: 2024
    )
    
    assert result[:years] == [2024], "Should only include 2024 data"
  end

  test "build_metric_chart_data should use default countries when none specified" do
    result = EuropeanMetricsService.build_metric_chart_data('population')
    
    # Should include Europe at minimum
    available_countries = result[:countries].keys
    assert available_countries.include?('europe'), "Should include Europe by default"
    
    # Should include some other countries with population data
    assert available_countries.length >= 1, "Should include at least Europe"
  end

  # Test error handling
  test "calculate_europe_aggregate should raise error for unknown calculation method" do
    assert_raises RuntimeError do
      EuropeanMetricsService.calculate_europe_aggregate('population', method: :unknown_method)
    end
  end

  test "should handle empty data gracefully" do
    # Test with a metric that doesn't exist
    result = EuropeanMetricsService.latest_metric_for_countries('nonexistent_metric', @key_countries)
    assert result.empty?, "Should return empty hash for nonexistent metric"
  end

  # Test integration with EuropeanCountriesHelper
  test "should properly use European countries helper for population adjustments" do
    # This tests that the service properly integrates with EuropeanCountriesHelper
    # by checking that transcontinental countries are handled
    countries = EuropeanMetricsService.countries_with_metric_data('population')
    
    if countries.include?('russia')
      # If Russia has data, verify the calculation considers the European portion
      result = EuropeanMetricsService.calculate_europe_aggregate('population', method: :simple_sum, min_countries: 1)
      assert result.present?, "Should calculate European totals with transcontinental adjustments"
    end
  end

  # Test metric metadata functionality
  test "should handle metric metadata correctly" do
    result = EuropeanMetricsService.build_metric_chart_data('population', countries: ['europe'])
    
    assert result[:metadata].present?, "Should include metadata"
    
    # Check that metadata has reasonable structure
    metadata = result[:metadata]
    assert metadata.is_a?(Hash), "Metadata should be a hash"
  end

  # Test year range handling
  test "should handle year ranges correctly" do
    # Test with valid year range
    result_2024 = EuropeanMetricsService.build_metric_chart_data('population', 
      countries: ['europe'], 
      start_year: 2024, 
      end_year: 2024
    )
    assert result_2024[:years].include?(2024), "Should include 2024"
    
    # Test with broader range
    result_range = EuropeanMetricsService.build_metric_chart_data('population',
      countries: ['europe'],
      start_year: 2023,
      end_year: 2024
    )
    assert result_range[:years].length >= 1, "Should include available years in range"
  end

  # Test service consistency
  test "repeated calls should return consistent results" do
    result1 = EuropeanMetricsService.latest_metric_for_countries('population', ['europe'])
    result2 = EuropeanMetricsService.latest_metric_for_countries('population', ['europe'])
    
    assert_equal result1, result2, "Repeated calls should return identical results"
  end

  # Test calculation methods individually
  test "simple_sum method should sum values correctly" do
    # This tests the simple sum calculation for population
    result = EuropeanMetricsService.calculate_europe_aggregate('population', method: :simple_sum, min_countries: 1)
    
    # Should return aggregated population for Europe (around 745M in our fixtures)
    assert result[:metric_value] > 700_000_000, "Europe population should be substantial"
    assert result[:metric_value] < 800_000_000, "Europe population should be reasonable"
  end

  test "population_weighted method should calculate weighted averages correctly" do
    # This tests the population-weighted calculation for GDP
    result = EuropeanMetricsService.calculate_europe_aggregate('gdp_per_capita_ppp', method: :population_weighted)
    
    # Should return reasonable GDP per capita for Europe
    assert result[:metric_value] > 20_000, "Europe GDP per capita should be substantial"
    assert result[:metric_value] < 100_000, "Europe GDP per capita should be reasonable"
  end
end