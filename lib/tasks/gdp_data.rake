namespace :gdp_data do
  desc "Fetch and store GDP per capita PPP data from Our World in Data"
  task fetch: :environment do
    GdpDataService.fetch_and_store_gdp_data
  end

  desc "Show latest GDP data for key countries"
  task show_latest: :environment do
    key_countries = ['germany', 'france', 'italy', 'spain', 'usa', 'china', 'india', 'european_union']
    latest_data = GdpDataService.latest_gdp_for_countries(key_countries)
    
    puts "Latest GDP per capita PPP data:"
    puts "=" * 40
    
    latest_data.each do |country, data|
      gdp_formatted = "$#{(data[:value]).round}"
      puts "  #{country}: #{gdp_formatted} (#{data[:year]})"
    end
  end

  desc "Calculate Europe GDP per capita from individual countries"
  task calculate_europe: :environment do
    GdpDataService.calculate_europe_gdp_per_capita
  end

  desc "Clear all GDP data"
  task clear: :environment do
    count = Metric.for_metric('gdp_per_capita_ppp').count
    Metric.for_metric('gdp_per_capita_ppp').delete_all
    puts "Cleared #{count} GDP records"
  end
end