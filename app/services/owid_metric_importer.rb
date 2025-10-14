# Generic service for importing metrics from Our World in Data
# Handles fetching, storing, and calculating aggregates for any OWID metric
#
# Metrics are configured in config/owid_metrics.yml
# Just add a metric there, commit, and deploy - the app does the rest!
class OwidMetricImporter
  # Load metrics from YAML file
  def self.load_configs
    config_file = Rails.root.join("config", "owid_metrics.yml")
    return {} unless File.exist?(config_file)

    raw_configs = YAML.load_file(config_file) || {}

    # Convert to symbol keys and filter enabled metrics
    raw_configs.each_with_object({}) do |(key, config), result|
      next unless config["enabled"] != false # Include if enabled is true or not specified

      result[key] = {
        owid_slug: config["owid_slug"],
        start_year: config["start_year"],
        end_year: config["end_year"],
        unit: config["unit"],
        description: config["description"],
        category: config["category"] || "social", # Default to social if not specified
        aggregation_method: config["aggregation_method"]&.to_sym || :population_weighted
      }
    end
  end

  # Fallback to hardcoded configs if YAML not found (backward compatibility)
  FALLBACK_CONFIGS = {
    "health_expenditure_gdp_percent" => {
      owid_slug: "total-healthcare-expenditure-gdp",
      start_year: 2000,
      end_year: 2024,
      unit: "% of GDP",
      description: "Health expenditure as a percentage of GDP",
      category: "health",
      aggregation_method: :population_weighted
    },
    "life_satisfaction" => {
      owid_slug: "happiness-cantril-ladder",
      start_year: 2010,
      end_year: 2024,
      unit: "score (0-10)",
      description: "Life satisfaction score on the Cantril Ladder",
      category: "social",
      aggregation_method: :population_weighted
    },
    "child_mortality_rate" => {
      owid_slug: "child-mortality",
      start_year: 1990,
      end_year: 2024,
      unit: "%",
      description: "Child mortality rate (deaths per 100 live births)",
      category: "development",
      aggregation_method: :population_weighted
    },
    "electricity_access" => {
      owid_slug: "share-of-the-population-with-access-to-electricity",
      start_year: 1990,
      end_year: 2024,
      unit: "%",
      description: "Access to electricity (% of population)",
      category: "development",
      aggregation_method: :population_weighted
    }
  }

  # Get configs from YAML or fallback
  def self.yaml_configs
    @yaml_configs ||= load_configs
    @yaml_configs.any? ? @yaml_configs : FALLBACK_CONFIGS
  end

  # Runtime configs for dynamic imports (not persisted)
  @runtime_configs = {}

  class << self
    attr_accessor :runtime_configs

    # Get all configs (YAML + runtime)
    def all_configs
      yaml_configs.merge(@runtime_configs)
    end

    # Reload configs from YAML (useful after editing the file)
    def reload_configs!
      @yaml_configs = load_configs
    end

    # Import a single metric
    def import_metric(metric_name, verbose: true, config: nil)
      # Use provided config or look it up
      metric_config = config || all_configs[metric_name]

      unless metric_config
        return { error: "Unknown metric: #{metric_name}" }
      end

      puts "Importing #{metric_name}..." if verbose

      # Fetch data from OWID
      result = OurWorldInDataService.fetch_chart_data(
        metric_config[:owid_slug],
        start_year: metric_config[:start_year],
        end_year: metric_config[:end_year]
      )

      return result if result[:error]

      # Store the data
      stored_count = store_metric_data(result, metric_name, metric_config, verbose)

      # Calculate aggregates
      calculate_aggregates(metric_name, metric_config, verbose) if stored_count > 0

      puts "✅ #{metric_name} imported: #{stored_count} records" if verbose

      { success: true, stored_count: stored_count }
    end

    # Import all configured metrics
    def import_all_metrics(verbose: true)
      puts "\n🌍 Importing all OWID metrics..." if verbose
      puts "=" * 60 if verbose

      results = {}
      total_stored = 0

      all_configs.keys.each do |metric_name|
        result = import_metric(metric_name, verbose: verbose)
        results[metric_name] = result
        total_stored += result[:stored_count] if result[:stored_count]
        puts "" if verbose # blank line between metrics
      end

      if verbose
        puts "=" * 60
        puts "✅ All metrics imported: #{total_stored} total records"
      end

      results
    end

    # Import only metrics from a specific category
    def import_category(category_metrics, verbose: true)
      category_metrics.each do |metric_name|
        import_metric(metric_name, verbose: verbose)
      end
    end

    # Add a new metric configuration dynamically
    def add_metric_config(metric_name, owid_slug:, start_year: 2000, end_year: 2024, unit: nil, description: nil, aggregation_method: :population_weighted)
      config = {
        owid_slug: owid_slug,
        start_year: start_year,
        end_year: end_year,
        unit: unit,
        description: description,
        aggregation_method: aggregation_method
      }

      @runtime_configs[metric_name] = config
      config
    end

    # List all available metrics
    def list_metrics
      all_configs.keys
    end

    # Get configuration for a metric
    def get_config(metric_name)
      all_configs[metric_name]
    end

    private

    def store_metric_data(result, metric_name, config, verbose)
      stored_count = 0
      skipped_count = 0

      result[:countries].each do |country_key, country_data|
        country_data[:data].each do |year, value|
          # Skip if value is nil or empty
          next if value.nil? || value.to_s.strip.empty?

          # Skip years before 1900 (matches Metric model validation)
          if year < 1900
            skipped_count += 1
            next
          end

          # Convert to float and skip if invalid
          numeric_value = value.to_f
          next if numeric_value.nan? || numeric_value.infinite?

          # Determine unit (prefer config, then metadata, then empty)
          unit_value = config[:unit] || result.dig(:metadata, :unit).presence || ""
          next if unit_value.blank?

          # Use upsert-style operation
          metric = Metric.find_or_initialize_by(
            country: country_key,
            metric_name: metric_name,
            year: year
          )

          metric.assign_attributes(
            metric_value: numeric_value,
            unit: unit_value,
            source: result.dig(:metadata, :source) || "Our World in Data",
            description: config[:description] || result.dig(:metadata, :description)
          )

          begin
            metric.save!
            stored_count += 1
          rescue ActiveRecord::RecordInvalid => e
            puts "   ⚠️  Failed to save #{country_key} #{year}: #{e.message}" if verbose
          end
        end
      end

      if verbose
        puts "   → Stored #{stored_count} records across #{result[:countries].size} countries"
        puts "   → Skipped #{skipped_count} pre-1900 records" if skipped_count > 0
      end
      stored_count
    end

    def calculate_aggregates(metric_name, config, verbose)
      # Calculate Europe aggregate
      puts "   → Calculating Europe aggregate..." if verbose
      EuropeanMetricsService.calculate_europe_aggregate(metric_name)

      # Calculate EU-27 aggregate
      puts "   → Calculating EU-27 aggregate..." if verbose
      EuropeanMetricsService.calculate_group_aggregate(
        metric_name,
        country_keys: EuropeanMetricsService::EU27_COUNTRIES,
        target_key: "european_union"
      )
    rescue => e
      puts "   ⚠️  Warning: Aggregate calculation failed: #{e.message}" if verbose
    end
  end
end
