namespace :metrics do
  desc "Import all enabled metrics from all sources (OWID + ILO)"
  task import: :environment do
    puts "\n" + "=" * 70
    puts "📊 UNIFIED METRIC IMPORT"
    puts "=" * 70

    # Show summary before import
    summary = MetricImporter.summary
    puts "\nConfiguration summary:"
    puts "  Total metrics configured: #{summary[:total]}"
    puts "  By source: #{summary[:by_source].map { |k, v| "#{k.upcase}=#{v}" }.join(', ')}"
    puts "  By category: #{summary[:by_category].map { |k, v| "#{k}=#{v}" }.join(', ')}"
    puts ""

    # Run the import
    results = MetricImporter.import_all(verbose: true)

    # Show results
    puts "\n" + "=" * 70
    puts "📈 IMPORT RESULTS"
    puts "=" * 70

    successful = results[:metrics].count { |_, r| r[:success] }
    failed = results[:metrics].count { |_, r| r[:error] }

    puts "  Successful: #{successful}"
    puts "  Failed: #{failed}"
    puts "  Total records: #{results[:total_records]}"

    if failed > 0
      puts "\n  Failed metrics:"
      results[:metrics].select { |_, r| r[:error] }.each do |name, result|
        puts "    - #{name}: #{result[:error]}"
      end
    end
  end

  desc "Import metrics from a specific source (owid or ilo)"
  task :import_source, [ :source ] => :environment do |_t, args|
    source = args[:source]&.to_sym

    unless %i[owid ilo].include?(source)
      puts "Usage: rails metrics:import_source[owid] or rails metrics:import_source[ilo]"
      exit 1
    end

    puts "\n📊 Importing #{source.upcase} metrics..."
    results = MetricImporter.import_by_source(source, verbose: true)

    puts "\nImported #{results[:total_records]} records from #{results[:metrics].size} metrics"
  end

  desc "Import metrics from a specific category"
  task :import_category, [ :category ] => :environment do |_t, args|
    category = args[:category]

    unless category
      puts "Usage: rails metrics:import_category[economy]"
      puts "Categories: economy, social, development, health, environment, innovation"
      exit 1
    end

    puts "\n📊 Importing #{category} metrics..."
    results = MetricImporter.import_by_category(category, verbose: true)

    puts "\nImported #{results[:total_records]} records from #{results[:metrics].size} metrics"
  end

  desc "Import a single metric by name"
  task :import_one, [ :metric_name ] => :environment do |_t, args|
    metric_name = args[:metric_name]

    unless metric_name
      puts "Usage: rails metrics:import_one[gdp_per_capita_ppp]"
      puts "\nAvailable metrics:"
      MetricImporter.list_metrics.each { |m| puts "  - #{m}" }
      exit 1
    end

    result = MetricImporter.import_metric(metric_name, verbose: true)

    if result[:error]
      puts "❌ Import failed: #{result[:error]}"
    else
      puts "✅ Imported #{result[:stored_count]} records"
    end
  end

  desc "List all configured metrics"
  task list: :environment do
    puts "\n📋 CONFIGURED METRICS"
    puts "=" * 70

    summary = MetricImporter.summary
    puts "Total: #{summary[:total]} metrics"
    puts ""

    %i[owid ilo].each do |source|
      metrics = MetricImporter.list_by_source(source)
      next if metrics.empty?

      puts "#{source.upcase} (#{metrics.size}):"
      metrics.each do |name|
        config = MetricImporter.get_config(name)
        status = config[:enabled] ? "✓" : "✗"
        preferred = config[:preferred] ? " ⭐" : ""
        puts "  #{status} #{name}#{preferred}"
        puts "      #{config[:description]}" if config[:description]
      end
      puts ""
    end
  end

  desc "Show database statistics for all metrics"
  task stats: :environment do
    puts "\n📊 DATABASE STATISTICS"
    puts "=" * 70

    MetricImporter.list_metrics.sort.each do |metric_name|
      records = Metric.where(metric_name: metric_name)
      next if records.count.zero?

      config = MetricImporter.get_config(metric_name)
      source = config[:source]&.upcase || "?"

      countries = records.distinct.pluck(:country).count
      years = records.distinct.pluck(:year)
      europe = records.find_by(country: "europe", year: years.max)

      printf "%-40s [%4s] %5d records, %2d countries, %d-%d\n",
             metric_name, source, records.count, countries, years.min, years.max

      if europe
        printf "    └─ Europe %d: %s %s\n",
               years.max, europe.metric_value.round(2), europe.unit
      end
    end
  end

  desc "Compare OWID and ILO labor productivity data"
  task compare_productivity: :environment do
    puts "\n📊 LABOR PRODUCTIVITY: OWID vs ILO"
    puts "=" * 70

    year = 2023
    countries = %w[germany france usa china india europe]

    printf "\n%-20s %18s %18s %10s\n", "Country", "OWID ($/hr)", "ILO ($/hr)", "Diff %"
    puts "-" * 70

    countries.each do |country|
      owid = Metric.find_by(metric_name: "labor_productivity_per_hour", country: country, year: year)
      ilo = Metric.find_by(metric_name: "labor_productivity_per_hour_ilo", country: country, year: year)

      owid_val = owid&.metric_value
      ilo_val = ilo&.metric_value

      diff = if owid_val && ilo_val
               ((ilo_val - owid_val) / owid_val * 100).round(1)
      else
               nil
      end

      printf "%-20s %18s %18s %10s\n",
             country.humanize.titleize,
             owid_val ? "$#{owid_val.round(2)}" : "N/A",
             ilo_val ? "$#{ilo_val.round(2)}" : "N/A",
             diff ? "#{diff > 0 ? '+' : ''}#{diff}%" : "-"
    end
  end

  desc "Reload configuration from YAML"
  task reload: :environment do
    MetricImporter.reload_configs!
    puts "✅ Configuration reloaded"
    puts "   #{MetricImporter.configs.size} metrics configured"
  end

  desc "Diagnose data issues for a metric"
  task :diagnose, [ :metric_name ] => :environment do |_t, args|
    metric_name = args[:metric_name] || "healthy_life_expectancy"

    puts "\n" + "=" * 70
    puts "🔍 DIAGNOSTIC REPORT: #{metric_name}"
    puts "=" * 70

    # Check database records
    total_records = Metric.where(metric_name: metric_name).count
    puts "\n📊 Database Status:"
    puts "   Total records: #{total_records}"

    if total_records > 0
      countries_with_data = Metric.where(metric_name: metric_name).distinct.pluck(:country)
      years_range = Metric.where(metric_name: metric_name).pluck(:year).minmax
      puts "   Countries with data: #{countries_with_data.count}"
      puts "   Year range: #{years_range[0]} - #{years_range[1]}"

      # Check key countries
      key_countries = %w[europe european_union usa india china germany france italy spain netherlands belgium austria ireland portugal greece slovakia slovenia finland]
      puts "\n📍 Key Country Status:"
      key_countries.each do |country|
        record = Metric.where(metric_name: metric_name, country: country).order(:year).last
        if record
          puts "   ✅ #{country.ljust(20)} #{record.year}: #{record.metric_value.round(2)}"
        else
          puts "   ❌ #{country.ljust(20)} NO DATA"
        end
      end
    end

    # Test OWID fetch
    puts "\n🌐 Testing OWID Data Fetch:"
    config = MetricImporter.configs[metric_name]
    if config && config[:owid_slug]
      begin
        result = OurWorldInDataService.fetch_chart_data(config[:owid_slug], start_year: 2020, end_year: 2021)
        countries_fetched = result[:countries].count { |_, d| d[:data].any? }
        puts "   OWID slug: #{config[:owid_slug]}"
        puts "   Countries with data from OWID: #{countries_fetched}"

        # Show sample for missing countries
        missing = %w[ireland portugal greece slovakia slovenia].select do |c|
          Metric.where(metric_name: metric_name, country: c).none?
        end

        if missing.any?
          puts "\n   Sample data for missing countries:"
          missing.each do |c|
            data = result[:countries][c]
            if data && data[:data].any?
              puts "     #{c}: #{data[:data].inspect} (OWID has data!)"
            else
              puts "     #{c}: NOT IN OWID"
            end
          end
        end
      rescue => e
        puts "   ❌ OWID fetch failed: #{e.message}"
      end
    else
      puts "   ⚠️  No OWID config found for #{metric_name}"
    end

    puts "\n" + "=" * 70
    puts "💡 RECOMMENDATIONS:"
    if total_records == 0
      puts "   Run: rails metrics:import_one[#{metric_name}]"
    elsif Metric.where(metric_name: metric_name, country: "usa").none?
      puts "   USA/India/China data missing - reimport with:"
      puts "   rails metrics:import_one[#{metric_name}]"
    else
      puts "   Data looks complete!"
    end
    puts "=" * 70
  end
end

# Convenience aliases
namespace :import do
  desc "Alias for metrics:import"
  task all: "metrics:import"

  desc "Import only ILO data"
  task ilo: :environment do
    Rake::Task["metrics:import_source"].invoke("ilo")
  end

  desc "Import only OWID data"
  task owid: :environment do
    Rake::Task["metrics:import_source"].invoke("owid")
  end
end
