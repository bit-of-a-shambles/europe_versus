namespace :health_social_data do
  desc "Fetch and store health expenditure as % of GDP"
  task fetch_health_expenditure: :environment do
    puts "Fetching health expenditure data..."
    result = HealthSocialDataService.fetch_and_store_health_expenditure_gdp
    
    if result[:error]
      puts "❌ Error: #{result[:error]}"
      exit 1
    else
      puts "✅ Successfully stored health expenditure data"
      count = Metric.where(metric_name: 'health_expenditure_gdp_percent').count
      puts "   Total records: #{count}"
      
      # Show sample data
      europe_latest = Metric.where(
        country: 'europe',
        metric_name: 'health_expenditure_gdp_percent'
      ).order(year: :desc).first
      
      if europe_latest
        puts "   Latest Europe value: #{europe_latest.metric_value}% (#{europe_latest.year})"
      end
    end
  end

  desc "Fetch and store life satisfaction (happiness) data"
  task fetch_life_satisfaction: :environment do
    puts "Fetching life satisfaction data..."
    result = HealthSocialDataService.fetch_and_store_life_satisfaction
    
    if result[:error]
      puts "❌ Error: #{result[:error]}"
      exit 1
    else
      puts "✅ Successfully stored life satisfaction data"
      count = Metric.where(metric_name: 'life_satisfaction').count
      puts "   Total records: #{count}"
      
      # Show sample data
      europe_latest = Metric.where(
        country: 'europe',
        metric_name: 'life_satisfaction'
      ).order(year: :desc).first
      
      if europe_latest
        puts "   Latest Europe value: #{europe_latest.metric_value} (#{europe_latest.year})"
      end
    end
  end

  desc "Fetch all health and social metrics"
  task fetch_all: :environment do
    puts "\n🏥 Fetching all health and social metrics..."
    puts "=" * 60
    
    tasks = [
      'health_social_data:fetch_health_expenditure',
      'health_social_data:fetch_life_satisfaction'
    ]
    
    tasks.each do |task_name|
      puts "\n"
      Rake::Task[task_name].invoke
    end
    
    puts "\n" + "=" * 60
    puts "✅ All health and social metrics fetched"
  end

  desc "Show latest health expenditure values"
  task show_health_expenditure: :environment do
    countries = ['europe', 'european_union', 'usa', 'china', 'india', 'germany', 'france', 'italy', 'spain']
    
    puts "\n🏥 Health Expenditure as % of GDP (Latest Available)"
    puts "=" * 80
    
    countries.each do |country|
      metric = Metric.where(
        country: country,
        metric_name: 'health_expenditure_gdp_percent'
      ).order(year: :desc).first
      
      if metric
        printf "%-20s: %6.2f%% (%d)\n", country.titleize, metric.metric_value, metric.year
      else
        printf "%-20s: No data\n", country.titleize
      end
    end
  end

  desc "Show latest life satisfaction values"
  task show_life_satisfaction: :environment do
    countries = ['europe', 'european_union', 'usa', 'china', 'india', 'germany', 'france', 'italy', 'spain']
    
    puts "\n😊 Life Satisfaction Score (0-10 scale, Latest Available)"
    puts "=" * 80
    
    countries.each do |country|
      metric = Metric.where(
        country: country,
        metric_name: 'life_satisfaction'
      ).order(year: :desc).first
      
      if metric
        printf "%-20s: %4.2f (%d)\n", country.titleize, metric.metric_value, metric.year
      else
        printf "%-20s: No data\n", country.titleize
      end
    end
  end
end
