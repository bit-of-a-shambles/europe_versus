namespace :data do
  desc "Initial data setup - Run once on fresh deployment to populate all data"
  task initialize: :environment do
    puts "🚀 Starting initial data population..."
    puts "=" * 60
    puts "This will take approximately 2-3 minutes."
    puts "=" * 60
    
    start_time = Time.current
    errors = []
    
    # Step 1: Population data (REQUIRED FIRST)
    puts "\n📊 Step 1/7: Fetching population data..."
    puts "   → This is required for weighted calculations"
    begin
      Rake::Task['data:fetch_population'].invoke
      puts "   ✅ Population data loaded"
    rescue => e
      error_msg = "Population fetch failed: #{e.message}"
      errors << error_msg
      puts "   ❌ #{error_msg}"
    end
    
    # Step 2: GDP data
    puts "\n💰 Step 2/7: Fetching GDP data..."
    begin
      Rake::Task['gdp_data:fetch'].invoke
      puts "   ✅ GDP data loaded"
    rescue => e
      error_msg = "GDP fetch failed: #{e.message}"
      errors << error_msg
      puts "   ❌ #{error_msg}"
    end
    
    # Step 3: Development metrics
    puts "\n📈 Step 3/7: Fetching development metrics..."
    begin
      Rake::Task['data:fetch_development'].invoke
      puts "   ✅ Development metrics loaded"
    rescue => e
      error_msg = "Development metrics fetch failed: #{e.message}"
      errors << error_msg
      puts "   ❌ #{error_msg}"
    end
    
    # Step 4: Calculate Europe population aggregate
    puts "\n🇪🇺 Step 4/7: Calculating Europe population aggregate..."
    begin
      Rake::Task['data:calculate_europe_population'].invoke
      puts "   ✅ Europe population aggregate calculated"
    rescue => e
      error_msg = "Europe population calculation failed: #{e.message}"
      errors << error_msg
      puts "   ❌ #{error_msg}"
    end
    
    # Step 5: Calculate Europe GDP aggregate
    puts "\n💶 Step 5/7: Calculating Europe GDP aggregate..."
    begin
      Rake::Task['gdp_data:calculate_europe'].invoke
      puts "   ✅ Europe GDP aggregate calculated"
    rescue => e
      error_msg = "Europe GDP calculation failed: #{e.message}"
      errors << error_msg
      puts "   ❌ #{error_msg}"
    end
    
    # Step 6: Normalize units
    puts "\n🔧 Step 6/7: Normalizing units..."
    begin
      Rake::Task['data:normalize_units'].invoke
      puts "   ✅ Units normalized"
    rescue => e
      error_msg = "Unit normalization failed: #{e.message}"
      errors << error_msg
      puts "   ❌ #{error_msg}"
    end
    
    # Step 7: Enrich descriptions
    puts "\n📝 Step 7/7: Enriching descriptions..."
    begin
      Rake::Task['data:enrich_aggregate_descriptions'].invoke
      puts "   ✅ Descriptions enriched"
    rescue => e
      error_msg = "Description enrichment failed: #{e.message}"
      errors << error_msg
      puts "   ❌ #{error_msg}"
    end
    
    # Summary
    end_time = Time.current
    duration = (end_time - start_time).round(2)
    
    puts "\n" + "=" * 60
    if errors.empty?
      puts "✅ INITIALIZATION COMPLETE!"
      puts "=" * 60
      puts "⏱️  Time taken: #{duration} seconds"
      
      # Show data summary
      puts "\n📊 Data Summary:"
      puts "   • Population records: #{Metric.for_metric('population').count}"
      puts "   • GDP records: #{Metric.for_metric('gdp_per_capita_ppp').count}"
      puts "   • Child mortality records: #{Metric.for_metric('child_mortality_rate').count}"
      puts "   • Electricity access records: #{Metric.for_metric('electricity_access').count}"
      puts "   • Total metrics: #{Metric.count}"
      puts "   • Countries covered: #{Metric.distinct.count(:country)}"
      
      puts "\n🎉 Your application is ready to use!"
      puts "   Visit your app to see the statistics in action."
    else
      puts "⚠️  INITIALIZATION COMPLETED WITH ERRORS"
      puts "=" * 60
      puts "⏱️  Time taken: #{duration} seconds"
      puts "\n❌ Errors encountered:"
      errors.each_with_index do |error, i|
        puts "   #{i + 1}. #{error}"
      end
      puts "\n💡 Please review the errors above and fix any issues."
      puts "   You can re-run this task to retry failed steps."
    end
    puts "=" * 60
  end
  
  desc "Update data - Run after adding new statistics or to refresh existing data"
  task update: :environment do
    puts "🔄 Starting data update..."
    puts "=" * 60
    puts "This will fetch the latest data and recalculate aggregates."
    puts "=" * 60
    
    start_time = Time.current
    errors = []
    
    # Step 1: Fetch all data sources
    puts "\n📊 Step 1/4: Fetching latest data from all sources..."
    
    # Population (always update first)
    print "   • Population data... "
    begin
      Rake::Task['data:fetch_population'].reenable
      Rake::Task['data:fetch_population'].invoke
      puts "✅"
    rescue => e
      puts "❌"
      errors << "Population: #{e.message}"
    end
    
    # GDP
    print "   • GDP data... "
    begin
      Rake::Task['gdp_data:fetch'].reenable
      Rake::Task['gdp_data:fetch'].invoke
      puts "✅"
    rescue => e
      puts "❌"
      errors << "GDP: #{e.message}"
    end
    
    # Development metrics
    print "   • Development metrics... "
    begin
      Rake::Task['data:fetch_development'].reenable
      Rake::Task['data:fetch_development'].invoke
      puts "✅"
    rescue => e
      puts "❌"
      errors << "Development metrics: #{e.message}"
    end
    
    # Step 2: Recalculate all Europe aggregates
    puts "\n🇪🇺 Step 2/4: Recalculating Europe aggregates..."
    
    metrics_to_aggregate = ['population', 'gdp_per_capita_ppp', 'child_mortality_rate', 'electricity_access']
    
    metrics_to_aggregate.each do |metric_name|
      print "   • #{metric_name.humanize}... "
      begin
        EuropeanMetricsService.calculate_europe_aggregate(metric_name)
        puts "✅"
      rescue => e
        puts "❌"
        errors << "Europe aggregate for #{metric_name}: #{e.message}"
      end
    end
    
    # Step 3: Recalculate EU-27 aggregates
    puts "\n🇪🇺 Step 3/4: Recalculating EU-27 aggregates..."
    
    metrics_to_aggregate.each do |metric_name|
      print "   • #{metric_name.humanize}... "
      begin
        EuropeanMetricsService.calculate_group_aggregate(
          metric_name,
          country_keys: EuropeanMetricsService::EU27_COUNTRIES,
          target_key: 'european_union'
        )
        puts "✅"
      rescue => e
        puts "❌"
        errors << "EU-27 aggregate for #{metric_name}: #{e.message}"
      end
    end
    
    # Step 4: Normalize and enrich
    puts "\n🔧 Step 4/4: Normalizing units and enriching descriptions..."
    
    print "   • Normalizing units... "
    begin
      Rake::Task['data:normalize_units'].reenable
      Rake::Task['data:normalize_units'].invoke
      puts "✅"
    rescue => e
      puts "❌"
      errors << "Unit normalization: #{e.message}"
    end
    
    print "   • Enriching descriptions... "
    begin
      Rake::Task['data:enrich_aggregate_descriptions'].reenable
      Rake::Task['data:enrich_aggregate_descriptions'].invoke
      puts "✅"
    rescue => e
      puts "❌"
      errors << "Description enrichment: #{e.message}"
    end
    
    # Summary
    end_time = Time.current
    duration = (end_time - start_time).round(2)
    
    puts "\n" + "=" * 60
    if errors.empty?
      puts "✅ DATA UPDATE COMPLETE!"
      puts "=" * 60
      puts "⏱️  Time taken: #{duration} seconds"
      
      # Show updated summary
      puts "\n📊 Updated Data Summary:"
      puts "   • Population records: #{Metric.for_metric('population').count}"
      puts "   • GDP records: #{Metric.for_metric('gdp_per_capita_ppp').count}"
      puts "   • Child mortality records: #{Metric.for_metric('child_mortality_rate').count}"
      puts "   • Electricity access records: #{Metric.for_metric('electricity_access').count}"
      puts "   • Total metrics: #{Metric.count}"
      puts "   • Countries covered: #{Metric.distinct.count(:country)}"
      puts "   • Latest update: #{Metric.maximum(:updated_at)&.strftime('%Y-%m-%d %H:%M:%S')}"
      
      puts "\n🎉 All data is up to date!"
    else
      puts "⚠️  DATA UPDATE COMPLETED WITH ERRORS"
      puts "=" * 60
      puts "⏱️  Time taken: #{duration} seconds"
      puts "\n❌ Errors encountered:"
      errors.each_with_index do |error, i|
        puts "   #{i + 1}. #{error}"
      end
      puts "\n💡 Please review the errors above and fix any issues."
    end
    puts "=" * 60
  end
end
