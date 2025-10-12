# Test script to debug view data
puts "Testing HomeController data..."

# Simulate what happens in the controller
gdp_data = begin
  key_countries = ['europe', 'usa', 'india', 'china']
  latest_data = GdpDataService.latest_gdp_for_countries(key_countries)
  { countries: latest_data, year: latest_data.values.first&.dig(:year) || 2024 }
rescue StandardError => e
  puts 'GDP Error: ' + e.message
  { error: true }
end

population_data = begin
  key_countries = ['europe', 'european_union', 'usa', 'india', 'china']
  latest_data = PopulationDataService.latest_population_for_countries(key_countries)
  { countries: latest_data, year: latest_data.values.first&.dig(:year) || 2023 }
rescue StandardError => e
  puts 'Population Error: ' + e.message
  { error: true }
end

puts "GDP data error: #{gdp_data[:error]}"
puts "Population data error: #{population_data[:error]}"
puts "Population data keys: #{population_data[:countries].keys.inspect}" if population_data[:countries]
puts "Population year: #{population_data[:year]}"

# Test the condition used in the view
if population_data && !population_data[:error]
  puts "View would show dynamic data"
  
  # Test each country
  regional_countries = [
    { key: 'europe', name: 'Europe' },
    { key: 'european_union', name: 'EU' },
    { key: 'usa', name: 'United States' },
    { key: 'india', name: 'India' },
    { key: 'china', name: 'China' }
  ]
  
  regional_countries.each do |country|
    pop_data = population_data[:countries][country[:key]]
    if pop_data && pop_data[:value]
      puts "#{country[:name]}: #{pop_data[:value].to_i} (#{pop_data[:year]})"
    else
      puts "#{country[:name]}: No data found"
    end
  end
else  
  puts "View would show fallback data"
end