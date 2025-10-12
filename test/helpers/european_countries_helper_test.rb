require "test_helper"

class EuropeanCountriesHelperTest < ActiveSupport::TestCase
  include EuropeanCountriesHelper

  # Test basic functionality
  test "all_european_countries should return comprehensive list" do
    countries = EuropeanCountriesHelper.all_european_countries
    
    assert countries.is_a?(Array), "Should return an array"
    assert countries.size >= 45, "Should have at least 45 European countries"
    
    # Test major European countries are included
    major_countries = %w[germany france italy spain netherlands poland sweden denmark 
                        finland austria belgium ireland portugal greece hungary romania
                        croatia bulgaria slovakia slovenia estonia latvia lithuania
                        luxembourg malta cyprus switzerland norway united_kingdom iceland]
    
    major_countries.each do |country|
      assert countries.include?(country), "Should include #{country}"
    end
    
    # Test transcontinental countries are included
    transcontinental = %w[russia turkey azerbaijan]
    transcontinental.each do |country|
      assert countries.include?(country), "Should include transcontinental country #{country}"
    end
    
    # Test small states are included
    small_states = %w[andorra monaco san_marino vatican]
    small_states.each do |country|
      assert countries.include?(country), "Should include small state #{country}"
    end
  end

  test "all_european_countries should not include non-European countries" do
    countries = EuropeanCountriesHelper.all_european_countries
    
    non_european = %w[usa china india japan brazil canada mexico australia]
    non_european.each do |country|
      assert_not countries.include?(country), "Should not include non-European country #{country}"
    end
  end

  # Test population factor functionality
  test "population_factor should return correct factors for transcontinental countries" do
    # Test Russia (77% European)
    assert_equal 0.77, EuropeanCountriesHelper.population_factor('russia')
    
    # Test Turkey (14% European)
    assert_equal 0.14, EuropeanCountriesHelper.population_factor('turkey')
    
    # Test Azerbaijan (30% European)
    assert_equal 0.30, EuropeanCountriesHelper.population_factor('azerbaijan')
  end

  test "population_factor should return 1.0 for fully European countries" do
    fully_european = %w[germany france italy spain netherlands poland sweden denmark]
    
    fully_european.each do |country|
      assert_equal 1.0, EuropeanCountriesHelper.population_factor(country),
                   "#{country} should have population factor of 1.0"
    end
  end

  test "population_factor should return 1.0 for unknown countries" do
    assert_equal 1.0, EuropeanCountriesHelper.population_factor('unknown_country')
    assert_equal 1.0, EuropeanCountriesHelper.population_factor('usa')
    assert_equal 1.0, EuropeanCountriesHelper.population_factor(nil)
  end

  # Test european_population calculation
  test "european_population should apply population factors correctly" do
    # Test Russia with 144M population -> 77% = ~111M
    russia_european = EuropeanCountriesHelper.european_population('russia', 144_000_000)
    expected_russia = 144_000_000 * 0.77
    assert_equal expected_russia, russia_european
    
    # Test Turkey with 85M population -> 14% = ~12M
    turkey_european = EuropeanCountriesHelper.european_population('turkey', 85_000_000)
    expected_turkey = 85_000_000 * 0.14
    assert_equal expected_turkey, turkey_european
    
    # Test Azerbaijan with 10M population -> 30% = 3M
    azerbaijan_european = EuropeanCountriesHelper.european_population('azerbaijan', 10_000_000)
    expected_azerbaijan = 10_000_000 * 0.30
    assert_equal expected_azerbaijan, azerbaijan_european
  end

  test "european_population should return full population for fully European countries" do
    # Test Germany
    germany_population = 84_000_000
    germany_european = EuropeanCountriesHelper.european_population('germany', germany_population)
    assert_equal germany_population, germany_european
    
    # Test France
    france_population = 68_000_000
    france_european = EuropeanCountriesHelper.european_population('france', france_population)
    assert_equal france_population, france_european
  end

  test "european_population should handle zero and negative values" do
    assert_equal 0, EuropeanCountriesHelper.european_population('russia', 0)
    assert_equal 0, EuropeanCountriesHelper.european_population('germany', -100)
  end

  test "european_population should handle nil country or population" do
    assert_equal 0, EuropeanCountriesHelper.european_population(nil, 1000000)
    assert_equal 0, EuropeanCountriesHelper.european_population('germany', nil)
    assert_equal 0, EuropeanCountriesHelper.european_population(nil, nil)
  end

  # Test countries_with_gdp_data filter
  test "countries_with_gdp_data should filter countries with available data" do
    available_countries = ['germany', 'france', 'usa', 'china', 'nonexistent']
    result = EuropeanCountriesHelper.countries_with_gdp_data(available_countries)
    
    # Should only return European countries that are in the available list
    assert result.include?('germany'), "Should include Germany"
    assert result.include?('france'), "Should include France"
    assert_not result.include?('usa'), "Should not include USA (not European)"
    assert_not result.include?('china'), "Should not include China (not European)"
    assert_not result.include?('nonexistent'), "Should not include nonexistent country"
  end

  test "countries_with_gdp_data should handle empty input" do
    result = EuropeanCountriesHelper.countries_with_gdp_data([])
    assert result.empty?, "Should return empty array for empty input"
  end

  test "countries_with_gdp_data should handle nil input" do
    result = EuropeanCountriesHelper.countries_with_gdp_data(nil)
    assert result.empty?, "Should return empty array for nil input"
  end

  # Test regional categorization
  test "should include countries from all European regions" do
    countries = EuropeanCountriesHelper.all_european_countries
    
    # Western Europe
    western = %w[germany france netherlands belgium luxembourg austria switzerland]
    western.each { |c| assert countries.include?(c), "Missing Western European country #{c}" }
    
    # Northern Europe
    northern = %w[sweden norway denmark finland iceland estonia latvia lithuania]
    northern.each { |c| assert countries.include?(c), "Missing Northern European country #{c}" }
    
    # Southern Europe
    southern = %w[italy spain portugal greece malta cyprus albania bosnia_herzegovina]
    southern.each { |c| assert countries.include?(c), "Missing Southern European country #{c}" }
    
    # Eastern Europe
    eastern = %w[poland hungary romania bulgaria slovakia slovenia croatia serbia]
    eastern.each { |c| assert countries.include?(c), "Missing Eastern European country #{c}" }
    
    # Transcontinental
    transcontinental = %w[russia turkey azerbaijan]
    transcontinental.each { |c| assert countries.include?(c), "Missing transcontinental country #{c}" }
  end

  # Test data consistency
  test "EUROPEAN_COUNTRIES constant should have correct structure" do
    assert defined?(EuropeanCountriesHelper::EUROPEAN_COUNTRIES), "Should have EUROPEAN_COUNTRIES constant"
    
    countries_hash = EuropeanCountriesHelper::EUROPEAN_COUNTRIES
    assert countries_hash.is_a?(Hash), "EUROPEAN_COUNTRIES should be a hash"
    
    # Test that all values are hashes with population_factor
    countries_hash.each do |country, info|
      assert country.is_a?(String), "Country key should be string: #{country}"
      assert info.is_a?(Hash), "Country info should be hash for #{country}"
      assert info.key?(:population_factor), "Should have population_factor for #{country}"
      
      factor = info[:population_factor]
      assert factor.is_a?(Float), "Population factor should be float for #{country}"
      assert factor > 0, "Population factor should be positive for #{country}"
      assert factor <= 1.0, "Population factor should not exceed 1.0 for #{country}"
    end
  end

  test "should have consistent transcontinental adjustments" do
    # Verify the specific adjustment factors are reasonable
    
    # Russia: 77% (European part includes most of population)
    russia_factor = EuropeanCountriesHelper.population_factor('russia')
    assert russia_factor > 0.5, "Russia should have majority European population"
    assert russia_factor < 0.9, "Russia should not be fully European"
    
    # Turkey: 14% (small European part in Thrace)
    turkey_factor = EuropeanCountriesHelper.population_factor('turkey')
    assert turkey_factor > 0.1, "Turkey should have some European population"
    assert turkey_factor < 0.2, "Turkey should have small European percentage"
    
    # Azerbaijan: 30% (significant part in Europe)
    azerbaijan_factor = EuropeanCountriesHelper.population_factor('azerbaijan')
    assert azerbaijan_factor > 0.2, "Azerbaijan should have substantial European part"
    assert azerbaijan_factor < 0.4, "Azerbaijan should not be majority European"
  end

  # Test edge cases
  test "should handle string case variations" do
    # Test that the helper works with different cases
    assert_equal 0.77, EuropeanCountriesHelper.population_factor('russia')
    assert_equal 0.77, EuropeanCountriesHelper.population_factor('RUSSIA')
    assert_equal 0.77, EuropeanCountriesHelper.population_factor('Russia')
  end

  test "should handle country name variations" do
    # Test common variations
    countries = EuropeanCountriesHelper.all_european_countries
    
    # Should use standardized names
    assert countries.include?('united_kingdom'), "Should use united_kingdom"
    assert_not countries.include?('uk'), "Should not use UK abbreviation"
    assert_not countries.include?('great_britain'), "Should not use great_britain"
  end

  # Test mathematical correctness
  test "population calculations should be mathematically correct" do
    test_population = 1_000_000
    
    # Test that calculations are precise
    russia_result = EuropeanCountriesHelper.european_population('russia', test_population)
    expected = test_population * 0.77
    assert_equal expected, russia_result, "Russia calculation should be precise"
    
    # Test floating point precision
    large_population = 144_526_636 # Realistic Russia population
    russia_large = EuropeanCountriesHelper.european_population('russia', large_population)
    expected_large = large_population * 0.77
    assert_equal expected_large, russia_large, "Should handle large numbers precisely"
  end

  # Test helper integration
  test "helper should integrate well with service classes" do
    # Test that the helper works as expected when included in service classes
    countries_with_data = EuropeanCountriesHelper.countries_with_gdp_data(['germany', 'france', 'usa'])
    
    assert_equal 2, countries_with_data.size, "Should filter to European countries only"
    assert countries_with_data.include?('germany'), "Should include Germany"
    assert countries_with_data.include?('france'), "Should include France"
  end
end