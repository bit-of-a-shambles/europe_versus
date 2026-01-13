# Importer for ILO (International Labour Organization) labor statistics
# Fetches data from ILO SDMX API and stores in the Metric model
class IloMetricImporter
  include EuropeanCountriesHelper

  # Maximum retries for SQLite busy exceptions
  MAX_RETRIES = 5
  BASE_DELAY = 0.5 # seconds

  # Map of metric names to ILO indicator keys
  METRIC_MAPPINGS = {
    "labor_productivity_per_hour_ilo" => :labor_productivity_per_hour,
    "labor_productivity_per_worker_ilo" => :labor_productivity_per_worker
  }.freeze

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
    # Import all available ILO metrics
    # @param start_year [Integer] Start year for data range
    # @param end_year [Integer] End year for data range
    # @return [Hash] Summary of import results
    def import_all(start_year: 2000, end_year: 2024)
      results = {}

      METRIC_MAPPINGS.each do |metric_name, indicator|
        results[metric_name] = import_metric(metric_name, indicator, start_year: start_year, end_year: end_year)
      end

      # Also import comparison countries
      results[:comparison] = import_comparison_countries(start_year: start_year, end_year: end_year)

      results
    end

    # Import a specific metric for all European countries
    # @param metric_name [String] Name to use in the database
    # @param indicator [Symbol] ILO indicator key
    # @param start_year [Integer] Start year
    # @param end_year [Integer] End year
    # @return [Hash] Import results with :imported and :errors counts
    def import_metric(metric_name, indicator, start_year: 2000, end_year: 2024)
      Rails.logger.info "Importing ILO metric: #{metric_name} (#{indicator})"

      # Get all European countries
      countries = EuropeanCountriesHelper::EUROPEAN_COUNTRIES.keys

      # Fetch data from ILO
      result = IloDataService.fetch_indicator(indicator, countries: countries, start_year: start_year, end_year: end_year)

      if result[:error]
        Rails.logger.error "Failed to fetch ILO data: #{result[:error]}"
        return { imported: 0, errors: 1, error_message: result[:error] }
      end

      # Store the data in batches with retry logic
      imported = 0
      errors = 0
      unit = result.dig(:metadata, :unit) || "units"

      # Collect all records
      records = []
      result[:data].each do |country, years|
        years.each do |year, value|
          records << { country: country, year: year, value: value }
        end
      end

      # Save in batches
      records.each_slice(100) do |batch|
        with_retry do
          Metric.transaction do
            batch.each do |record|
              begin
                Metric.find_or_initialize_by(
                  metric_name: metric_name,
                  country: record[:country],
                  year: record[:year]
                ).tap do |metric|
                  metric.metric_value = record[:value]
                  metric.unit = unit
                  metric.description = "Labor productivity per hour worked (ILO Modelled Estimates)"
                  metric.save!
                end
                imported += 1
              rescue ActiveRecord::RecordInvalid => e
                Rails.logger.error "Failed to save #{metric_name} for #{record[:country]} #{record[:year]}: #{e.message}"
                errors += 1
              end
            end
          end
        end
      end

      Rails.logger.info "Imported #{imported} records for #{metric_name}, #{errors} errors"
      { imported: imported, errors: errors, countries: result[:countries].length }
    end

    # Import data for comparison countries (USA, China, India)
    def import_comparison_countries(start_year: 2000, end_year: 2024)
      Rails.logger.info "Importing ILO data for comparison countries"

      comparison_countries = %w[usa china india]
      imported = 0
      errors = 0

      METRIC_MAPPINGS.each do |metric_name, indicator|
        result = IloDataService.fetch_indicator(indicator, countries: comparison_countries, start_year: start_year, end_year: end_year)

        next if result[:error]

        unit = result.dig(:metadata, :unit) || "units"

        # Collect all records
        records = []
        result[:data].each do |country, years|
          years.each do |year, value|
            records << { country: country, year: year, value: value }
          end
        end

        # Save in batches with retry
        records.each_slice(100) do |batch|
          with_retry do
            Metric.transaction do
              batch.each do |record|
                begin
                  Metric.find_or_initialize_by(
                    metric_name: metric_name,
                    country: record[:country],
                    year: record[:year]
                  ).tap do |metric|
                    metric.metric_value = record[:value]
                    metric.unit = unit
                    metric.description = "Labor productivity (ILO Modelled Estimates)"
                    metric.save!
                  end
                  imported += 1
                rescue ActiveRecord::RecordInvalid => e
                  Rails.logger.error "Failed to save comparison data: #{e.message}"
                  errors += 1
                end
              end
            end
          end
        end
      end

      { imported: imported, errors: errors }
    end

    # Calculate and store European aggregate for labor productivity
    # Uses population-weighted average
    def calculate_europe_aggregate(metric_name: "labor_productivity_per_hour_ilo", start_year: 2000, end_year: 2024)
      Rails.logger.info "Calculating Europe aggregate for #{metric_name}"

      (start_year..end_year).each do |year|
        with_retry do
          # Get all country data for this year
          country_metrics = Metric.where(
            metric_name: metric_name,
            year: year
          ).where.not(country: %w[europe usa china india])

          next if country_metrics.count < 5 # Need at least 5 countries

          # Calculate simple average (could be improved with population weighting)
          values = country_metrics.pluck(:metric_value).compact
          next if values.empty?

          avg_value = values.sum / values.length

          # Get unit from existing records
          unit = country_metrics.first&.unit || "2021 PPP $ per hour"

          # Store the aggregate
          Metric.find_or_initialize_by(
            metric_name: metric_name,
            country: "europe",
            year: year
          ).tap do |metric|
            metric.metric_value = avg_value.round(2)
            metric.unit = unit
            metric.description = "European average labor productivity (ILO data, #{country_metrics.count} countries)"
            metric.save!
          end
        end
      end
    end
  end
end
