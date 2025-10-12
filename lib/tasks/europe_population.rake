namespace :data do
  desc "Calculate Europe population using modular European metrics service"
  task calculate_europe_population: :environment do
    # Use the new modular European metrics service
    EuropeanMetricsService.calculate_europe_aggregate('population', method: :simple_sum, min_countries: 20)
  end
  
  desc "Show Europe population summary"
  task europe_population_summary: :environment do
    puts "Europe Population Data Summary"
    puts "=" * 40
    
    europe_data = Metric.where(country: 'europe', metric_name: 'population').order(:year)
    
    if europe_data.empty?
      puts "No Europe population data found. Run 'rake data:calculate_europe_population' first."
      return
    end
    
    puts "Total records: #{europe_data.count}"
    puts "Year range: #{europe_data.first.year} to #{europe_data.last.year}"
    puts
    
    puts "Recent population trends:"
    europe_data.last(10).each do |record|
      population_millions = (record.metric_value / 1_000_000).round(1)
      puts "  #{record.year}: #{population_millions}M people"
    end
    
    puts
    puts "Latest: #{(europe_data.last.metric_value / 1_000_000).round(1)}M people (#{europe_data.last.year})"
  end
end