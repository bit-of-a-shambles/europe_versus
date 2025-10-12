namespace :data do
  desc "Fetch and store development metrics from Our World in Data"
  task fetch_development: :environment do
    puts "🔄 Fetching development metrics from Our World in Data..."
    
    # Fetch and store child mortality data
    puts "\n📊 Fetching child mortality data..."
    child_mortality_result = DevelopmentDataService.fetch_and_store_child_mortality
    if child_mortality_result[:error]
      puts "❌ Error fetching child mortality data: #{child_mortality_result[:error]}"
    else
      puts "✅ Successfully fetched and stored child mortality data"
    end
    
    # Fetch and store electricity access data
    puts "\n💡 Fetching electricity access data..."
    electricity_result = DevelopmentDataService.fetch_and_store_electricity_access
    if electricity_result[:error]
      puts "❌ Error fetching electricity access data: #{electricity_result[:error]}"
    else
      puts "✅ Successfully fetched and stored electricity access data"
    end
    
    puts "\n🎉 Development data fetch complete!"
    
    # Show summary
    child_mortality_count = Metric.where(metric_name: 'child_mortality_rate').count
    electricity_count = Metric.where(metric_name: 'electricity_access').count
    
    puts "\n📈 Data summary:"
    puts "   Child Mortality records: #{child_mortality_count}"
    puts "   Electricity Access records: #{electricity_count}"
  end
  
  desc "Fetch and store all OWID metrics"
  task fetch_all: :environment do
    puts "🔄 Fetching all metrics from Our World in Data..."
    
    # Run existing tasks
    Rake::Task['data:fetch_population'].invoke rescue puts "⚠️  Population data task not found"
    Rake::Task['data:fetch_gdp'].invoke rescue puts "⚠️  GDP data task not found"
    
    # Run development metrics
    Rake::Task['data:fetch_development'].invoke
    
    puts "\n🎉 All data fetch complete!"
  end
end