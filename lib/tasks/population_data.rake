namespace :data do
  desc "Fetch population data from Our World in Data and store in database"
  task fetch_population: :environment do
    puts "Starting population data fetch..."
    
    start_time = Time.current
    success = PopulationDataService.fetch_and_store_population_data(
      start_year: 1990,
      end_year: 2024
    )
    
    end_time = Time.current
    duration = (end_time - start_time).round(2)
    
    if success
      total_records = Metric.for_metric('population').count
      puts "\n✅ Population data fetch completed successfully!"
      puts "📊 Total population records in database: #{total_records}"
      puts "⏱️  Time taken: #{duration} seconds"
      
      # Show some sample data
      puts "\n📈 Sample latest population data:"
      sample_data = PopulationDataService.latest_population_for_countries(['germany', 'france', 'usa', 'china', 'india'])
      sample_data.each do |country, data|
        formatted_population = ActionController::Base.helpers.number_with_delimiter(data[:value].to_i)
        puts "  #{country.humanize}: #{formatted_population} (#{data[:year]})"
      end
    else
      puts "\n❌ Population data fetch failed!"
      exit 1
    end
  end
  
  desc "Show population statistics"
  task population_stats: :environment do
    total_records = Metric.for_metric('population').count
    countries_count = Metric.for_metric('population').distinct.count(:country)
    year_range = Metric.for_metric('population').pluck(:year).minmax
    
    puts "📊 Population Data Statistics"
    puts "=" * 30
    puts "Total records: #{total_records}"
    puts "Countries covered: #{countries_count}"
    puts "Year range: #{year_range[0]} - #{year_range[1]}"
    
    puts "\n🌍 Latest population by region:"
    latest_data = PopulationDataService.latest_population_for_countries
    
    # Group by region for display
    eu_countries = %w[germany france italy spain netherlands poland sweden denmark finland austria belgium ireland portugal greece czechia hungary romania croatia bulgaria slovakia slovenia estonia latvia lithuania luxembourg malta cyprus]
    other_eu = %w[switzerland norway united_kingdom iceland]
    aggregates = %w[european_union europe_central_asia]
    global = %w[usa china india]
    
    [
      ['Major EU Countries', eu_countries],
      ['Other European', other_eu], 
      ['Aggregates', aggregates],
      ['Global Comparisons', global]
    ].each do |group_name, countries|
      puts "\n#{group_name}:"
      countries.each do |country|
        if latest_data[country]
          data = latest_data[country]
          formatted_pop = ActionController::Base.helpers.number_with_delimiter(data[:value].to_i)
          puts "  #{country.humanize}: #{formatted_pop} (#{data[:year]})"
        end
      end
    end
  end
end