# Net Earnings Importer - Computes derived per-hour earnings metrics
#
# After Eurostat (annual_net_earnings_pps) and OWID (annual_working_hours)
# are imported, this service computes:
#   - annual_net_earnings_per_hour_pps: net PPP earnings / working hours
#   - annual_net_earnings_per_hour_nominal: net EUR earnings / working hours
#
# These are computed metrics that combine two data sources.
# Run this AFTER MetricImporter.import_all has populated the base metrics.
#
class NetEarningsImporter
  COMPUTED_METRICS = {
    "annual_net_earnings_per_hour_pps" => {
      numerator: "annual_net_earnings_pps",
      denominator: "annual_working_hours",
      unit: "PPS per hour",
      description: "Net earnings per hour worked in purchasing power standard. Calculated from annual net earnings " \
        "(Eurostat earn_nt_net) divided by annual working hours (Penn World Table/OWID). Shows actual take-home " \
        "compensation per hour of work, adjusted for cost-of-living differences.",
      category: "economy"
    },
    "annual_net_earnings_per_hour_nominal" => {
      numerator: "annual_net_earnings_nominal",
      denominator: "annual_working_hours",
      unit: "€ per hour",
      description: "Net earnings per hour worked in nominal euros. Calculated from annual net earnings " \
        "(Eurostat earn_nt_net) divided by annual working hours (OWID/Penn World Table). " \
        "Does not adjust for cost-of-living differences between countries.",
      category: "economy"
    }
  }.freeze

  SOURCE = "Eurostat / Penn World Table (computed)"

  class << self
    # Compute all per-hour metrics from already-imported base data
    def import_all(verbose: true)
      puts "\n💰 Computing derived net earnings metrics..." if verbose

      total_stored = 0

      COMPUTED_METRICS.each do |metric_name, config|
        stored = compute_metric(metric_name, config, verbose: verbose)
        total_stored += stored

        # Calculate aggregates
        if stored > 0
          puts "   → Calculating Europe aggregate (population_weighted)..." if verbose
          EuropeanMetricsService.calculate_europe_aggregate(metric_name, method: :population_weighted)
          EuropeanMetricsService.calculate_all_regional_aggregates(metric_name, options: { method: :population_weighted })
        end
      end

      puts "✅ Net earnings per hour: #{total_stored} total records computed" if verbose
      { success: true, stored_count: total_stored, source: :computed }
    end

    private

    def compute_metric(metric_name, config, verbose: true)
      numerator_name = config[:numerator]
      denominator_name = config[:denominator]

      # Load all numerator data grouped by (country, year)
      numerators = Metric.where(metric_name: numerator_name)
        .pluck(:country, :year, :metric_value)
        .each_with_object({}) { |(c, y, v), h| h[[c, y]] = v }

      # Load all denominator data grouped by (country, year)
      denominators = Metric.where(metric_name: denominator_name)
        .pluck(:country, :year, :metric_value)
        .each_with_object({}) { |(c, y, v), h| h[[c, y]] = v }

      if numerators.empty?
        puts "   ⚠️ No #{numerator_name} data found — skipping #{metric_name}" if verbose
        return 0
      end

      if denominators.empty?
        puts "   ⚠️ No #{denominator_name} data found — skipping #{metric_name}" if verbose
        return 0
      end

      stored = 0
      records = []

      numerators.each do |(country, year), num_value|
        den_value = denominators[[country, year]]
        # If exact year not available, try nearest year for hours (OWID may lag by 1 year)
        den_value ||= denominators[[country, year - 1]]
        next unless den_value && den_value > 0

        per_hour = num_value / den_value

        records << {
          country: country,
          metric_name: metric_name,
          year: year,
          metric_value: per_hour.round(4),
          unit: config[:unit],
          source: SOURCE,
          description: config[:description]
        }
      end

      records.each_slice(100) do |batch|
        MetricImporter.with_retry do
          Metric.transaction do
            batch.each do |attrs|
              metric = Metric.find_or_initialize_by(
                country: attrs[:country],
                metric_name: attrs[:metric_name],
                year: attrs[:year]
              )
              metric.assign_attributes(attrs)
              begin
                metric.save!
                stored += 1
              rescue ActiveRecord::RecordInvalid => e
                puts "   ⚠️ Failed: #{attrs[:country]} #{attrs[:year]}: #{e.message}" if verbose
              end
            end
          end
        end
      end

      matched_countries = records.map { |r| r[:country] }.uniq.size
      matched_years = records.map { |r| r[:year] }.uniq.sort
      puts "   ✅ #{metric_name}: #{stored} records (#{matched_countries} countries, years #{matched_years.first}–#{matched_years.last})" if verbose
      stored
    end
  end
end
