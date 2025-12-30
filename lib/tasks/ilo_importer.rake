namespace :ilo do
  desc "Import labor productivity data from ILO (International Labour Organization)"
  task import: :environment do
    puts "Importing ILO labor productivity data..."
    puts "=" * 50

    results = IloMetricImporter.import_all(start_year: 2000, end_year: 2025)

    results.each do |metric, result|
      if result[:error_message]
        puts "#{metric}: ERROR - #{result[:error_message]}"
      else
        puts "#{metric}: #{result[:imported]} records imported, #{result[:errors]} errors"
        puts "  Countries: #{result[:countries]}" if result[:countries]
      end
    end

    puts "=" * 50
    puts "Calculating European aggregates..."

    IloMetricImporter.calculate_europe_aggregate(metric_name: "labor_productivity_per_hour_ilo")
    IloMetricImporter.calculate_europe_aggregate(metric_name: "labor_productivity_per_worker_ilo")

    puts "Done!"

    # Show summary
    puts "\nDatabase summary:"
    %w[labor_productivity_per_hour_ilo labor_productivity_per_worker_ilo].each do |metric|
      count = Metric.where(metric_name: metric).count
      europe = Metric.where(metric_name: metric, country: "europe").order(year: :desc).first
      puts "  #{metric}: #{count} records"
      puts "    Europe 2024: $#{europe&.metric_value&.round(2)}/hr" if europe
    end
  end

  desc "Show ILO labor productivity data for a specific year"
  task :show, [ :year ] => :environment do |_t, args|
    year = args[:year]&.to_i || 2024

    puts "ILO Labor Productivity Data for #{year}"
    puts "=" * 60

    metrics = Metric.where(metric_name: "labor_productivity_per_hour_ilo", year: year)
                    .order(metric_value: :desc)

    metrics.each do |m|
      printf "  %-25s $%8.2f/hr\n", m.country.humanize.titleize, m.metric_value
    end
  end

  desc "Compare ILO data with OWID data for labor productivity"
  task compare_sources: :environment do
    puts "Comparing Labor Productivity Data Sources (2023)"
    puts "=" * 70

    countries = %w[germany france usa china india europe]

    printf "%-20s %15s %15s %15s\n", "Country", "ILO ($/hr)", "OWID ($/hr)", "Difference"
    puts "-" * 70

    countries.each do |country|
      ilo = Metric.find_by(metric_name: "labor_productivity_per_hour_ilo", country: country, year: 2023)
      owid = Metric.find_by(metric_name: "labor_productivity_per_hour", country: country, year: 2023)

      ilo_val = ilo&.metric_value
      owid_val = owid&.metric_value

      diff = if ilo_val && owid_val
               ((ilo_val - owid_val) / owid_val * 100).round(1)
      else
               "-"
      end

      printf "%-20s %15s %15s %14s%%\n",
             country.humanize.titleize,
             ilo_val ? "$#{ilo_val.round(2)}" : "N/A",
             owid_val ? "$#{owid_val.round(2)}" : "N/A",
             diff
    end
  end
end
