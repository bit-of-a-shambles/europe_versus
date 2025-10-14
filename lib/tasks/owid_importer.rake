namespace :owid do
  desc "Import a single OWID metric by name"
  task :import, [ :metric_name ] => :environment do |t, args|
    if args[:metric_name].blank?
      puts "Usage: bin/rails owid:import[metric_name]"
      puts "\nAvailable metrics:"
      OwidMetricImporter.list_metrics.each do |name|
        config = OwidMetricImporter.get_config(name)
        puts "  • #{name.ljust(35)} (#{config[:owid_slug]})"
      end
      exit 1
    end

    result = OwidMetricImporter.import_metric(args[:metric_name])

    if result[:error]
      puts "❌ Error: #{result[:error]}"
      exit 1
    end
  end

  desc "Import all configured OWID metrics"
  task import_all: :environment do
    OwidMetricImporter.import_all_metrics
  end

  desc "List all available OWID metrics"
  task list: :environment do
    puts "\n📊 Available OWID Metrics"
    puts "=" * 80

    OwidMetricImporter.list_metrics.each do |metric_name|
      config = OwidMetricImporter.get_config(metric_name)
      puts "\n#{metric_name.upcase.tr('_', ' ')}"
      puts "  OWID Slug:      #{config[:owid_slug]}"
      puts "  Year Range:     #{config[:start_year]}-#{config[:end_year]}"
      puts "  Unit:           #{config[:unit]}"
      puts "  Aggregation:    #{config[:aggregation_method]}"
      puts "  Description:    #{config[:description]}"
    end

    puts "\n" + "=" * 80
    puts "Total: #{OwidMetricImporter.list_metrics.count} metrics"
    puts "\nUsage: bin/rails owid:import[metric_name]"
  end

  desc "Show statistics for a metric"
  task :stats, [ :metric_name ] => :environment do |t, args|
    if args[:metric_name].blank?
      puts "Usage: bin/rails owid:stats[metric_name]"
      exit 1
    end

    metric_name = args[:metric_name]

    total = Metric.where(metric_name: metric_name).count
    countries = Metric.where(metric_name: metric_name).distinct.pluck(:country).count
    years = Metric.where(metric_name: metric_name).distinct.pluck(:year)

    puts "\n📊 Statistics for #{metric_name}"
    puts "=" * 60
    puts "Total records:     #{total}"
    puts "Countries:         #{countries}"
    puts "Year range:        #{years.min}-#{years.max}" if years.any?
    puts "Latest year:       #{years.max}" if years.any?

    # Show Europe values
    europe = Metric.where(country: "europe", metric_name: metric_name).order(year: :desc).first
    if europe
      puts "\nLatest Europe value:"
      puts "  #{europe.year}: #{europe.metric_value} #{europe.unit}"
    end

    # Show some country samples
    puts "\nSample country values (latest year):"
    [ "germany", "france", "usa", "china" ].each do |country|
      latest = Metric.where(country: country, metric_name: metric_name).order(year: :desc).first
      if latest
        printf "  %-20s: %10.2f %s (%d)\n", country.titleize, latest.metric_value, latest.unit, latest.year
      end
    end
  end

  desc "Quick add a new metric (generates configuration template)"
  task :scaffold, [ :metric_name, :owid_slug ] => :environment do |t, args|
    if args[:metric_name].blank? || args[:owid_slug].blank?
      puts "Usage: bin/rails owid:scaffold[metric_name,owid_slug]"
      puts "\nExample:"
      puts "  bin/rails owid:scaffold[co2_emissions,co2-emissions-per-capita]"
      exit 1
    end

    puts "\n📝 Add this to app/services/owid_metric_importer.rb in METRIC_CONFIGS:"
    puts "=" * 60
    puts <<~RUBY
      '#{args[:metric_name]}' => {
        owid_slug: '#{args[:owid_slug]}',
        start_year: 2000,  # Adjust as needed
        end_year: 2024,
        unit: 'UNIT_HERE',  # e.g., '% of GDP', 'kg', 'score (0-10)'
        description: 'DESCRIPTION_HERE',
        aggregation_method: :population_weighted  # or :sum, :average
      },
    RUBY
    puts "=" * 60
    puts "\nThen run: bin/rails owid:import[#{args[:metric_name]}]"
  end
end
