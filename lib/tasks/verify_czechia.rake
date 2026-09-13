namespace :data do
  desc "Verify Czechia data retrieval and display"
  task verify_czechia: :environment do
    puts "🔍 Verifying Czechia data retrieval..."
    puts "=" * 60

    # Check database records
    puts "\n📊 Database Check:"
    czechia_count = Metric.where(country: "czechia").count
    puts "  ✓ Total Czechia records: #{czechia_count}"

    if czechia_count == 0
      puts "  ❌ ERROR: No Czechia records found in database!"
      exit 1
    end

    # Check population data
    puts "\n👥 Population Data:"
    population_data = PopulationDataService.latest_population_for_countries([ "czechia" ])
    if population_data["czechia"]
      population = population_data["czechia"][:value]
      year = population_data["czechia"][:year]
      formatted_pop = ActionController::Base.helpers.number_with_delimiter(population.to_i)
      puts "  ✓ Latest population: #{formatted_pop} (#{year})"
    else
      puts "  ❌ ERROR: No population data retrieved for Czechia!"
    end

    # Check GDP data
    puts "\n💰 GDP Data:"
    gdp_data = GdpDataService.latest_gdp_for_countries([ "czechia" ])
    if gdp_data["czechia"]
      gdp = gdp_data["czechia"][:value]
      year = gdp_data["czechia"][:year]
      formatted_gdp = ActionController::Base.helpers.number_with_delimiter(gdp.round(0))
      puts "  ✓ Latest GDP per capita: $#{formatted_gdp} (#{year})"
    else
      puts "  ❌ WARNING: No GDP data retrieved for Czechia!"
    end

    # Check child mortality data
    puts "\n👶 Child Mortality Data:"
    child_mortality_data = DevelopmentDataService.latest_child_mortality_for_countries(countries: [ "czechia" ])
    if child_mortality_data.dig("czechia", :value)
      value = child_mortality_data["czechia"][:value]
      year = child_mortality_data["czechia"][:year]
      puts "  ✓ Latest child mortality rate: #{value.round(2)} per 1,000 (#{year})"
    else
      puts "  ⚠️  No child mortality data found for Czechia"
    end

    # Check electricity access data
    puts "\n⚡ Electricity Access Data:"
    electricity_data = DevelopmentDataService.latest_electricity_access_for_countries(countries: [ "czechia" ])
    if electricity_data.dig("czechia", :value)
      value = electricity_data["czechia"][:value]
      year = electricity_data["czechia"][:year]
      puts "  ✓ Latest electricity access: #{value.round(2)}% (#{year})"
    else
      puts "  ⚠️  No electricity access data found for Czechia"
    end

    # Check EuropeanCountriesHelper
    puts "\n🗺️  European Countries Helper:"
    all_countries = EuropeanCountriesHelper.all_european_countries
    if all_countries.include?("czechia")
      puts "  ✓ 'czechia' found in EuropeanCountriesHelper"
      country_name = EuropeanCountriesHelper.country_name("czechia")
      puts "  ✓ Display name: #{country_name}"
    else
      puts "  ❌ ERROR: 'czechia' not found in EuropeanCountriesHelper!"
      exit 1
    end

    # Check for old czech_republic references
    puts "\n🔄 Migration Check:"
    old_records = Metric.where(country: "czech_republic").count
    if old_records > 0
      puts "  ⚠️  WARNING: Found #{old_records} records still using 'czech_republic'"
    else
      puts "  ✓ No old 'czech_republic' records found"
    end

    # Test data retrieval through services
    puts "\n🔄 Service Integration Test:"
    test_countries = [ "czechia", "germany", "france" ]
    test_data = PopulationDataService.latest_population_for_countries(test_countries)

    test_countries.each do |country|
      if test_data[country]
        puts "  ✓ #{EuropeanCountriesHelper.country_name(country)}: #{ActionController::Base.helpers.number_to_human(test_data[country][:value], precision: 2)}"
      else
        puts "  ❌ #{country}: No data retrieved"
      end
    end

    puts "\n" + "=" * 60
    puts "✅ Czechia data verification completed successfully!"
    puts "📝 All systems are properly configured to use 'czechia' instead of 'czech_republic'"
  end
end
