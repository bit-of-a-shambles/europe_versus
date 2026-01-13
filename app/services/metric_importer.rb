# Unified Metric Importer - Multi-Source Data Import System
#
# Supports importing metrics from multiple data sources:
#   - OWID (Our World in Data)
#   - ILO (International Labour Organization)
#   - World Bank (World Bank Open Data)
#
# Configuration is read from config/metrics.yml
#
# Usage:
#   MetricImporter.import_all          # Import all enabled metrics
#   MetricImporter.import_metric("gdp_per_capita_ppp")  # Import specific metric
#   MetricImporter.import_by_source(:ilo)   # Import all ILO metrics
#   MetricImporter.import_by_category(:economy)  # Import by category
#
class MetricImporter
  CONFIG_FILE = Rails.root.join("config", "metrics.yml")

  # Supported data sources
  SOURCES = %i[owid ilo worldbank].freeze

  # SQLite retry configuration
  MAX_RETRIES = 5
  BASE_DELAY = 0.5 # seconds

  class << self
    # Retry block with exponential backoff for SQLite busy exceptions
    def with_retry(max_retries: MAX_RETRIES, &block)
      retries = 0
      begin
        yield
      rescue ActiveRecord::StatementInvalid => e
        if e.message.include?("database is locked") || e.message.include?("BusyException")
          retries += 1
          if retries <= max_retries
            delay = BASE_DELAY * (2 ** (retries - 1)) + rand(0.0..0.5)
            Rails.logger.warn "SQLite busy, retry #{retries}/#{max_retries} after #{delay.round(2)}s"
            sleep delay
            retry
          else
            Rails.logger.error "SQLite still busy after #{max_retries} retries, giving up"
            raise
          end
        else
          raise
        end
      end
    end

    # Load all metric configurations from YAML
    def load_configs
      return {} unless File.exist?(CONFIG_FILE)

      raw_configs = YAML.load_file(CONFIG_FILE) || {}

      raw_configs.each_with_object({}) do |(key, config), result|
        next unless config["enabled"] != false

        result[key] = symbolize_config(config)
      end
    end

    # Get all configs (cached)
    def configs
      @configs ||= load_configs
    end

    # Reload configs from file
    def reload_configs!
      @configs = load_configs
    end

    # Import all enabled metrics from all sources
    def import_all(verbose: true)
      puts "\n📊 Importing all metrics from all sources..." if verbose
      puts "=" * 70 if verbose

      results = { total_records: 0, metrics: {} }

      # CRITICAL: Import population data FIRST - it's required for all aggregate calculations
      # Population data comes from a separate service, not from metrics.yml
      ensure_population_data(verbose: verbose)

      # Import OWID metrics first (they're generally more reliable and include foundational data)
      # Then import ILO and WorldBank metrics
      sorted_configs = configs.sort_by do |_name, config|
        case config[:source]&.to_sym
        when :owid then 0
        when :worldbank then 1
        when :ilo then 2
        else 3
        end
      end

      sorted_configs.each do |metric_name, config|
        result = import_metric(metric_name, verbose: verbose, config: config)
        results[:metrics][metric_name] = result
        results[:total_records] += result[:stored_count] || 0
      end

      if verbose
        puts "=" * 70
        puts "✅ Import complete: #{results[:total_records]} total records"
        puts "   Metrics processed: #{results[:metrics].size}"
      end

      results
    end

    # Ensure population data exists - required for all aggregate calculations
    def ensure_population_data(verbose: true)
      existing_count = Metric.where(metric_name: "population").count

      if existing_count > 5000 # Assume we have enough data if > 5000 records
        puts "📊 Population data already exists (#{existing_count} records)" if verbose
        return true
      end

      puts "📊 Importing population data (required for aggregates)..." if verbose
      PopulationDataService.fetch_and_store_population

      new_count = Metric.where(metric_name: "population").count
      puts "   ✅ Population data ready: #{new_count} records" if verbose
      true
    rescue StandardError => e
      puts "   ⚠️  Failed to import population data: #{e.message}" if verbose
      false
    end

    # Import a single metric by name
    def import_metric(metric_name, verbose: true, config: nil)
      config ||= configs[metric_name]

      unless config
        error_msg = "Unknown metric: #{metric_name}"
        puts "❌ #{error_msg}" if verbose
        return { error: error_msg }
      end

      source = config[:source]&.to_sym

      case source
      when :owid
        import_owid_metric(metric_name, config, verbose: verbose)
      when :ilo
        import_ilo_metric(metric_name, config, verbose: verbose)
      when :worldbank
        import_worldbank_metric(metric_name, config, verbose: verbose)
      else
        error_msg = "Unknown source '#{source}' for metric #{metric_name}"
        puts "❌ #{error_msg}" if verbose
        { error: error_msg }
      end
    end

    # Import all metrics from a specific source
    def import_by_source(source, verbose: true)
      source = source.to_sym
      puts "\n📊 Importing all #{source.upcase} metrics..." if verbose

      matching = configs.select { |_, c| c[:source]&.to_sym == source }

      results = { total_records: 0, metrics: {} }

      matching.each do |metric_name, config|
        result = import_metric(metric_name, verbose: verbose, config: config)
        results[:metrics][metric_name] = result
        results[:total_records] += result[:stored_count] || 0
      end

      puts "✅ #{source.upcase}: #{results[:total_records]} records imported" if verbose
      results
    end

    # Import all metrics from a specific category
    def import_by_category(category, verbose: true)
      category = category.to_s
      puts "\n📊 Importing #{category} metrics..." if verbose

      matching = configs.select { |_, c| c[:category] == category }

      results = { total_records: 0, metrics: {} }

      matching.each do |metric_name, config|
        result = import_metric(metric_name, verbose: verbose, config: config)
        results[:metrics][metric_name] = result
        results[:total_records] += result[:stored_count] || 0
      end

      puts "✅ Category '#{category}': #{results[:total_records]} records imported" if verbose
      results
    end

    # List all available metrics
    def list_metrics
      configs.keys
    end

    # List metrics by source
    def list_by_source(source)
      configs.select { |_, c| c[:source]&.to_sym == source.to_sym }.keys
    end

    # List metrics by category
    def list_by_category(category)
      configs.select { |_, c| c[:category] == category.to_s }.keys
    end

    # Get configuration for a specific metric
    def get_config(metric_name)
      configs[metric_name]
    end

    # Get summary of available metrics
    def summary
      {
        total: configs.size,
        by_source: SOURCES.each_with_object({}) { |s, h| h[s] = list_by_source(s).size },
        by_category: configs.values.map { |c| c[:category] }.compact.tally,
        enabled: configs.count { |_, c| c[:enabled] != false },
        preferred: configs.select { |_, c| c[:preferred] }.keys
      }
    end

    private

    def symbolize_config(config)
      {
        source: config["source"]&.to_sym,
        owid_slug: config["owid_slug"],
        ilo_indicator: config["ilo_indicator"]&.to_sym,
        worldbank_indicator: config["worldbank_indicator"]&.to_sym,
        start_year: config["start_year"] || 2000,
        end_year: config["end_year"] || 2024,
        unit: config["unit"],
        description: config["description"],
        category: config["category"] || "social",
        aggregation_method: config["aggregation_method"]&.to_sym || :population_weighted,
        enabled: config["enabled"] != false,
        preferred: config["preferred"] == true
      }
    end

    # Import from OWID source
    def import_owid_metric(metric_name, config, verbose: true)
      puts "🌍 [OWID] Importing #{metric_name}..." if verbose

      unless config[:owid_slug]
        return { error: "Missing owid_slug for #{metric_name}" }
      end

      # Fetch data from OWID
      result = OurWorldInDataService.fetch_chart_data(
        config[:owid_slug],
        start_year: config[:start_year],
        end_year: config[:end_year]
      )

      return { error: result[:error] } if result[:error]

      # Store the data
      stored_count = store_owid_data(result, metric_name, config, verbose)

      # Calculate aggregates
      calculate_aggregates(metric_name, config, verbose) if stored_count > 0

      puts "   ✅ #{metric_name}: #{stored_count} records" if verbose
      { success: true, stored_count: stored_count, source: :owid }
    end

    # Import from ILO source
    def import_ilo_metric(metric_name, config, verbose: true)
      puts "🏢 [ILO] Importing #{metric_name}..." if verbose

      indicator = config[:ilo_indicator]
      unless indicator
        return { error: "Missing ilo_indicator for #{metric_name}" }
      end

      # Get all European countries + comparison countries
      european_countries = EuropeanCountriesHelper::EUROPEAN_COUNTRIES.keys
      comparison_countries = %w[usa china india]
      all_countries = european_countries + comparison_countries

      # Fetch data from ILO
      result = IloDataService.fetch_indicator(
        indicator,
        countries: all_countries,
        start_year: config[:start_year],
        end_year: config[:end_year]
      )

      return { error: result[:error] } if result[:error]

      # Store the data
      stored_count = store_ilo_data(result, metric_name, config, verbose)

      # Calculate aggregates
      calculate_aggregates(metric_name, config, verbose) if stored_count > 0

      puts "   ✅ #{metric_name}: #{stored_count} records" if verbose
      { success: true, stored_count: stored_count, source: :ilo }
    end

    # Import from World Bank source
    def import_worldbank_metric(metric_name, config, verbose: true)
      puts "🏦 [World Bank] Importing #{metric_name}..." if verbose

      indicator = config[:worldbank_indicator]
      unless indicator
        return { error: "Missing worldbank_indicator for #{metric_name}" }
      end

      # Fetch data from World Bank
      result = WorldBankDataService.fetch_indicator(
        indicator,
        start_year: config[:start_year],
        end_year: config[:end_year]
      )

      return { error: result[:error] } if result[:error]

      # Store the data
      stored_count = store_worldbank_data(result, metric_name, config, verbose)

      # Calculate aggregates
      calculate_aggregates(metric_name, config, verbose) if stored_count > 0

      puts "   ✅ #{metric_name}: #{stored_count} records" if verbose
      { success: true, stored_count: stored_count, source: :worldbank }
    end

    def store_owid_data(result, metric_name, config, verbose)
      stored_count = 0

      # Collect all records first
      records = []
      result[:countries].each do |country_key, country_data|
        country_data[:data].each do |year, value|
          next if value.nil? || value.to_s.strip.empty?
          next if year < 1900

          numeric_value = value.to_f
          next if numeric_value.nan? || numeric_value.infinite?

          unit_value = config[:unit] || result.dig(:metadata, :unit).presence || ""

          records << {
            country: country_key,
            metric_name: metric_name,
            year: year,
            metric_value: numeric_value,
            unit: unit_value,
            source: "Our World in Data",
            description: config[:description]
          }
        end
      end

      # Save in batches with retry logic
      records.each_slice(100) do |batch|
        with_retry do
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
                stored_count += 1
              rescue ActiveRecord::RecordInvalid => e
                puts "   ⚠️ Failed: #{attrs[:country]} #{attrs[:year]}: #{e.message}" if verbose
              end
            end
          end
        end
      end

      puts "   → Stored #{stored_count} records across #{result[:countries].size} countries" if verbose
      stored_count
    end

    def store_ilo_data(result, metric_name, config, verbose)
      stored_count = 0
      unit = config[:unit] || result.dig(:metadata, :unit) || "units"

      # Collect all records first
      records = []
      result[:data].each do |country_key, years|
        years.each do |year, value|
          next if value.nil?

          records << {
            country: country_key,
            metric_name: metric_name,
            year: year,
            metric_value: value.to_f,
            unit: unit,
            source: "ILO - Modelled Estimates",
            description: config[:description]
          }
        end
      end

      # Save in batches with retry logic
      records.each_slice(100) do |batch|
        with_retry do
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
                stored_count += 1
              rescue ActiveRecord::RecordInvalid => e
                puts "   ⚠️ Failed: #{attrs[:country]} #{attrs[:year]}: #{e.message}" if verbose
              end
            end
          end
        end
      end

      countries_count = result[:countries]&.length || result[:data].keys.length
      puts "   → Stored #{stored_count} records across #{countries_count} countries" if verbose
      stored_count
    end

    def store_worldbank_data(result, metric_name, config, verbose)
      stored_count = 0
      unit = config[:unit] || result.dig(:metadata, :unit) || "units"

      # Collect all records first
      records = []
      result[:data].each do |country_key, years|
        years.each do |year, value|
          next if value.nil?

          records << {
            country: country_key,
            metric_name: metric_name,
            year: year,
            metric_value: value.to_f,
            unit: unit,
            source: "World Bank",
            description: config[:description]
          }
        end
      end

      # Save in batches with retry logic
      records.each_slice(100) do |batch|
        with_retry do
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
                stored_count += 1
              rescue ActiveRecord::RecordInvalid => e
                puts "   ⚠️ Failed: #{attrs[:country]} #{attrs[:year]}: #{e.message}" if verbose
              end
            end
          end
        end
      end

      countries_count = result[:countries]&.length || result[:data].keys.length
      puts "   → Stored #{stored_count} records across #{countries_count} countries" if verbose
      stored_count
    end

    def calculate_aggregates(metric_name, config, verbose)
      # Map config aggregation_method to the method symbol used internally
      method_map = {
        sum: :simple_sum,
        population_weighted: :population_weighted,
        average: :population_weighted
      }
      aggregation_method = method_map[config[:aggregation_method]] || :population_weighted

      puts "   → Calculating Europe aggregate (#{aggregation_method})..." if verbose
      EuropeanMetricsService.calculate_europe_aggregate(metric_name, method: aggregation_method)

      puts "   → Calculating all regional aggregates (EU-27, Core EU, Eurozone, Non-Euro EU, Non-EU Europe)..." if verbose
      EuropeanMetricsService.calculate_all_regional_aggregates(metric_name, options: { method: aggregation_method })
    rescue => e
      puts "   ⚠️ Aggregate calculation failed: #{e.message}" if verbose
    end
  end
end
