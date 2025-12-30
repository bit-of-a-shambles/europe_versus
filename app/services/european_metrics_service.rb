class EuropeanMetricsService
  include EuropeanCountriesHelper

  # Major EU countries for averaging
  EU_COUNTRIES = [ "germany", "france", "italy", "spain", "netherlands", "poland", "sweden", "denmark", "finland", "austria", "belgium" ].freeze
  # Full EU27 membership (2020–present)
  EU27_COUNTRIES = [
    "germany", "france", "italy", "spain", "netherlands", "poland", "sweden",
    "denmark", "finland", "austria", "belgium", "ireland", "portugal", "greece",
    "czechia", "hungary", "romania", "croatia", "bulgaria", "slovakia",
    "slovenia", "estonia", "latvia", "lithuania", "luxembourg", "malta", "cyprus"
  ].freeze

  # Generic method to calculate Europe aggregate for any metric
  def self.calculate_europe_aggregate(metric_name, options = {})
    puts "Calculating Europe #{metric_name} from individual countries..."

    # Get countries that have data for this metric
    european_countries = countries_with_metric_data(metric_name)

    puts "  Including #{european_countries.size} European countries with #{metric_name} data:"
    european_countries.each_slice(8) do |batch|
      puts "    #{batch.join(', ')}"
    end

    # Determine calculation method based on metric type
    calculation_method = options[:method] || detect_calculation_method(metric_name)

    case calculation_method
    when :population_weighted
      calculate_population_weighted_average(metric_name, european_countries, options)
    when :simple_sum
      calculate_simple_sum(metric_name, european_countries, options)
    when :population_weighted_rate
      calculate_population_weighted_rate(metric_name, european_countries, options)
    else
      raise "Unknown calculation method: #{calculation_method}"
    end
  end

  private

  # Get European countries that have data for a specific metric
  def self.countries_with_metric_data(metric_name)
    available_countries = Metric.for_metric(metric_name).distinct.pluck(:country)
    EuropeanCountriesHelper.all_european_countries.select { |country| available_countries.include?(country) }
  end

  # Detect the appropriate calculation method based on metric name
  def self.detect_calculation_method(metric_name)
    case metric_name
    when "population"
      :simple_sum
    when "gdp_per_capita_ppp", "life_expectancy", "education_index", "happiness_score"
      :population_weighted
    when "birth_rate", "death_rate", "literacy_rate"
      :population_weighted_rate
    else
      :population_weighted # default
    end
  end

  # Calculate population-weighted average (for per capita metrics like GDP per capita)
  def self.calculate_population_weighted_average(metric_name, european_countries, options = {})
    requires_population = true

    # Get years with data
    metric_years = get_years_with_data(metric_name, european_countries)
    population_years = requires_population ? get_years_with_data("population", european_countries) : metric_years

    common_years = requires_population ? (metric_years & population_years) : metric_years
    stored_count = 0

    Metric.transaction do
      # Process years with both metric and population data
      common_years.each do |year|
        total_weighted_value = 0.0
        total_population = 0.0
        contributing_countries = 0

        european_countries.each do |country|
          metric_record = get_metric_record(metric_name, country, year)
          population_record = requires_population ? get_metric_record("population", country, year) : nil

          if metric_record && (!requires_population || population_record)
            european_population = requires_population ?
              EuropeanCountriesHelper.european_population(country, population_record.metric_value) : 1.0

            # Metric value * population = weighted contribution
            weighted_value = metric_record.metric_value * european_population
            total_weighted_value += weighted_value
            total_population += european_population
            contributing_countries += 1
          end
        end

        if total_population > 0
          europe_average = total_weighted_value / total_population
          description = "Population-weighted European average of #{metric_name.humanize} using country population weights; adjusted for transcontinental populations; #{contributing_countries} contributing countries."
          store_europe_metric(metric_name, year, europe_average, description)
          stored_count += 1
        end
      end

      # Handle extrapolation for missing years if needed
      if requires_population
        stored_count += handle_extrapolation(metric_name, european_countries, metric_years, population_years, common_years)
      end
    end

    puts "✅ Successfully calculated and stored #{stored_count} Europe #{metric_name} records"

    # Return the latest calculated record
    latest_record = Metric.where(country: "europe", metric_name: metric_name).order(:year).last
    if latest_record
      {
        metric_value: latest_record.metric_value,
        year: latest_record.year,
        unit: latest_record.unit,
        description: latest_record.description
      }
    else
      nil
    end
  end

  # Generic group aggregate calculator (e.g., EU27) with storage under target_key
  def self.calculate_group_aggregate(metric_name, country_keys:, target_key:, options: {})
    calculation_method = options[:method] || detect_calculation_method(metric_name)
    stored_count = 0

    case calculation_method
    when :population_weighted, :population_weighted_rate
      # Require population for weighting
      metric_years = get_years_with_data(metric_name, country_keys)
      population_years = get_years_with_data("population", country_keys)
      common_years = metric_years & population_years

      Metric.transaction do
        common_years.each do |year|
          total_weighted = 0.0
          total_pop = 0.0
          contributing = 0

          country_keys.each do |country|
            metric_record = get_metric_record(metric_name, country, year)
            pop_record = get_metric_record("population", country, year)
            next unless metric_record && pop_record

            european_population = EuropeanCountriesHelper.european_population(country, pop_record.metric_value)
            total_weighted += metric_record.metric_value * european_population
            total_pop += european_population
            contributing += 1
          end

          next if total_pop <= 0
          average = total_weighted / total_pop
          desc = "Population-weighted #{target_key.humanize} average of #{metric_name.humanize} using member populations; #{contributing} contributing countries."
          store_group_metric(metric_name, target_key, year, average, desc)
          stored_count += 1
        end
      end
    when :simple_sum
      years = get_years_with_data(metric_name, country_keys)
      Metric.transaction do
        years.each do |year|
          sum = 0.0
          contributing = 0
          country_keys.each do |country|
            metric_record = get_metric_record(metric_name, country, year)
            next unless metric_record
            value = if metric_name == "population"
              EuropeanCountriesHelper.european_population(country, metric_record.metric_value)
            else
              metric_record.metric_value * EuropeanCountriesHelper.population_factor(country)
            end
            sum += value
            contributing += 1
          end
          desc = metric_name == "population" ?
            "Total #{target_key.humanize} population (adjusted for transcontinental populations); #{contributing} contributing countries." :
            "Simple sum of #{metric_name.humanize} across #{target_key.humanize} members; #{contributing} contributing countries."
          store_group_metric(metric_name, target_key, year, sum, desc)
          stored_count += 1
        end
      end
    else
      # Default: treat as population-weighted
      return calculate_group_aggregate(metric_name, country_keys: country_keys, target_key: target_key, options: { method: :population_weighted })
    end

    stored_count
  end

  def self.store_group_metric(metric_name, country_key, year, value, description = nil)
    existing = Metric.for_metric(metric_name).for_country(country_key).where(year: year).first
    existing&.destroy

    unit = case metric_name
    when "population" then "people"
    when "gdp_per_capita_ppp" then "international_dollars"
    when "life_expectancy" then "years"
    when "birth_rate", "death_rate", "literacy_rate" then "rate"
    when "child_mortality_rate", "electricity_access" then "%"
    else "units"
    end

    default_desc = case metric_name
    when "population"
                     "Total #{country_key.humanize} population (sum of member populations, adjusted for transcontinental populations)."
    when "gdp_per_capita_ppp"
                     "Population-weighted #{country_key.humanize} GDP per capita (PPP) using member populations as weights; adjusted for transcontinental populations."
    when "child_mortality_rate"
                     "Population-weighted #{country_key.humanize} child mortality rate (deaths per 100 live births), using member populations as weights; adjusted for transcontinental populations."
    when "electricity_access"
                     "Population-weighted #{country_key.humanize} access to electricity (% of population), using member populations as weights; adjusted for transcontinental populations."
    else
                     "Calculated #{country_key.humanize} #{metric_name.humanize} from member country data."
    end

    Metric.create!(
      metric_name: metric_name,
      country: country_key,
      year: year,
      metric_value: value,
      unit: unit,
      source: "Calculated from member countries",
      description: description || default_desc
    )
  end

  # Calculate simple sum (for absolute metrics like total population)
  def self.calculate_simple_sum(metric_name, european_countries, options = {})
    metric_years = get_years_with_data(metric_name, european_countries)
    stored_count = 0

    Metric.transaction do
      metric_years.each do |year|
        total_value = 0.0
        contributing_countries = 0

        european_countries.each do |country|
          metric_record = get_metric_record(metric_name, country, year)

          if metric_record
            # Apply European portion adjustment for transcontinental countries
            european_value = case metric_name
            when "population"
              EuropeanCountriesHelper.european_population(country, metric_record.metric_value)
            else
              metric_record.metric_value * EuropeanCountriesHelper.population_factor(country)
            end

            total_value += european_value
            contributing_countries += 1
          end
        end

        # Require minimum number of countries to have reliable data
        min_countries = options[:min_countries] || 20
        if contributing_countries >= min_countries
          store_europe_metric(metric_name, year, total_value, "European #{metric_name} from #{contributing_countries} countries (adjusted for transcontinental countries)")
          stored_count += 1
        end
      end
    end

    puts "✅ Successfully calculated and stored #{stored_count} Europe #{metric_name} records"

    # Return the latest calculated record
    latest_record = Metric.where(country: "europe", metric_name: metric_name).order(:year).last
    if latest_record
      {
        metric_value: latest_record.metric_value,
        year: latest_record.year,
        unit: latest_record.unit,
        description: latest_record.description
      }
    else
      nil
    end
  end

  # Calculate population-weighted rate (for rate metrics like birth rate)
  def self.calculate_population_weighted_rate(metric_name, european_countries, options = {})
    # Similar to population_weighted but treats the metric as a rate
    calculate_population_weighted_average(metric_name, european_countries, options)
  end

  # Helper methods
  def self.get_years_with_data(metric_name, countries)
    Metric.for_metric(metric_name)
          .where(country: countries)
          .distinct
          .pluck(:year)
  end

  def self.get_metric_record(metric_name, country, year)
    Metric.for_metric(metric_name)
          .for_country(country)
          .where(year: year)
          .first
  end

  def self.store_europe_metric(metric_name, year, value, description = nil, source_unit: nil)
    # Delete existing record to avoid duplicates
    existing = Metric.for_metric(metric_name)
                    .for_country("europe")
                    .where(year: year)
                    .first
    existing&.destroy

    # Use provided source unit or look it up from existing data, or fall back to defaults
    unit = source_unit || get_unit_for_metric(metric_name)

    # Create new Europe aggregate record
    Metric.create!(
      metric_name: metric_name,
      country: "europe",
      year: year,
      metric_value: value,
      unit: unit,
      source: "Calculated from individual European countries",
      description: description || (
        case metric_name
        when "population"
          "Total European population (sum of country populations, adjusted for transcontinental populations)."
        when "gdp_per_capita_ppp"
          "Population-weighted European GDP per capita (PPP) using country populations as weights; adjusted for transcontinental populations."
        when "child_mortality_rate"
          "Population-weighted European child mortality rate (deaths per 100 live births), using country populations as weights; adjusted for transcontinental populations."
        when "electricity_access"
          "Population-weighted European access to electricity (% of population), using country populations as weights; adjusted for transcontinental populations."
        else
          "Calculated European #{metric_name.humanize} from country data."
        end
      )
    )
  end

  # Get the unit for a metric from existing data or OWID config
  def self.get_unit_for_metric(metric_name)
    # First try to get unit from existing country data
    sample_metric = Metric.where(metric_name: metric_name)
                          .where.not(country: [ "europe", "european_union" ])
                          .where.not(unit: [ nil, "", "units" ])
                          .first
    return sample_metric.unit if sample_metric&.unit.present?

    # Fall back to OWID config if available
    if defined?(OwidMetricImporter)
      config = OwidMetricImporter.all_configs[metric_name]
      return config[:unit] if config && config[:unit].present?
    end

    # Final fallback to hardcoded defaults
    case metric_name
    when "population"
      "people"
    when "gdp_per_capita_ppp"
      "international $"
    when "life_expectancy", "healthy_life_expectancy"
      "years"
    when "child_mortality_rate", "electricity_access"
      "%"
    else
      "units"
    end
  end

  def self.handle_extrapolation(metric_name, european_countries, metric_years, population_years, common_years)
    metric_only_years = metric_years - common_years
    latest_pop_year = population_years.max
    stored_count = 0

    # Minimum number of countries required for a valid aggregate (at least 10% of European countries)
    min_countries_for_aggregate = (european_countries.size * 0.1).ceil.clamp(5, 20)

    if latest_pop_year && metric_only_years.any?
      puts "  Extrapolating for years #{metric_only_years.join(', ')} using #{latest_pop_year} population weights..."

      metric_only_years.each do |year|
        total_weighted_value = 0.0
        total_population = 0.0
        contributing_countries = 0

        european_countries.each do |country|
          metric_record = get_metric_record(metric_name, country, year)
          population_record = get_metric_record("population", country, latest_pop_year)

          if metric_record && population_record
            european_population = EuropeanCountriesHelper.european_population(country, population_record.metric_value)
            weighted_value = metric_record.metric_value * european_population
            total_weighted_value += weighted_value
            total_population += european_population
            contributing_countries += 1
          end
        end

        # Only create aggregate if we have enough countries for a representative sample
        if total_population > 0 && contributing_countries >= min_countries_for_aggregate
          europe_average = total_weighted_value / total_population
          description = "Population-weighted European average of #{metric_name.humanize} using #{latest_pop_year} population weights (extrapolated); adjusted for transcontinental populations; #{contributing_countries} contributing countries."
          store_europe_metric(metric_name, year, europe_average, description)
          stored_count += 1
        elsif contributing_countries > 0 && contributing_countries < min_countries_for_aggregate
          puts "    Skipping year #{year}: only #{contributing_countries} countries have data (minimum #{min_countries_for_aggregate} required)"
        end
      end
    end

    stored_count
  end

  # Public method to get latest values for any metric
  def self.latest_metric_for_countries(metric_name, country_keys = nil)
    country_keys ||= EuropeanCountriesHelper.all_european_countries + [ "europe", "usa", "china", "india" ]
    Rails.logger.info "EuropeanMetricsService#latest_metric_for_countries - metric_name: #{metric_name}, country_keys: #{country_keys.inspect}"

    result = {}

    country_keys.each do |country|
      Rails.logger.info "EuropeanMetricsService - Processing country: #{country}"
      latest_record = Metric.for_metric(metric_name)
                           .for_country(country)
                           .order(:year)
                           .last

      # If EU27 requested but missing, calculate it on the fly
      if country == "european_union" && latest_record.nil?
        begin
          calculate_group_aggregate(metric_name, country_keys: EU27_COUNTRIES, target_key: "european_union", options: {})
          latest_record = Metric.for_metric(metric_name).for_country("european_union").order(:year).last
        rescue => e
          Rails.logger.warn "Failed to calculate EU27 for #{metric_name}: #{e.message}"
        end
      end

      Rails.logger.info "EuropeanMetricsService - Latest record for #{country}: #{latest_record.inspect}"

      if latest_record
        result[country] = {
          value: latest_record.metric_value,
          year: latest_record.year
        }
        Rails.logger.info "EuropeanMetricsService - Added to result for #{country}: #{result[country].inspect}"
      else
        Rails.logger.warn "EuropeanMetricsService - No record found for #{country}"
      end
    end

    Rails.logger.info "EuropeanMetricsService#latest_metric_for_countries - Final result: #{result.inspect}"
    result
  end

  # Build chart data for any metric
  def self.build_metric_chart_data(metric_name, options = {})
    start_year = options[:start_year] || 2000
    end_year = options[:end_year] || 2024

    # Get all available years in range
    years = Metric.for_metric(metric_name)
                  .where(year: start_year..end_year)
                  .distinct
                  .pluck(:year)
                  .sort

    # Get ALL available countries from database (not just a subset)
    available_countries = Metric.for_metric(metric_name).distinct.pluck(:country)
    requested_countries = options[:countries] || available_countries

    # Get countries data
    countries_data = {}

    # Process all requested countries
    requested_countries.each do |country_key|
      if available_countries.include?(country_key)
        # Country has direct database records
        country_data = Metric.for_metric(metric_name)
                            .for_country(country_key)
                            .where(year: start_year..end_year)
                            .order(:year)
                            .pluck(:year, :metric_value)
                            .to_h

        # Get human-readable name
        name = get_country_display_name(country_key)

        countries_data[country_key] = {
          name: name,
          data: country_data
        }
      elsif country_key == "europe" && available_countries.any? { |c| EU_COUNTRIES.include?(c) }
        # Calculate Europe aggregate if EU countries are available
        europe_data = {}
        years.each do |year|
          eu_values = []
          EU_COUNTRIES.each do |eu_country|
            next unless available_countries.include?(eu_country)
            value = Metric.where(metric_name: metric_name, country: eu_country, year: year).first&.metric_value
            eu_values << value if value
          end

          if eu_values.any?
            europe_data[year] = eu_values.sum / eu_values.count
          end
        end

        countries_data["europe"] = {
          name: "Europe",
          data: europe_data
        }
      end
    end

    {
      metadata: get_metric_metadata(metric_name),
      years: years,
      countries: countries_data
    }
  end

  private

  def self.get_country_display_name(country_key)
    # Use OurWorldInDataService mapping (most comprehensive)
    owid_mapping = OurWorldInDataService::COUNTRIES.invert
    return owid_mapping[country_key] if owid_mapping[country_key]

    # Try population service mapping as fallback
    pop_mapping = PopulationDataService::COUNTRIES.invert
    return pop_mapping[country_key] if pop_mapping[country_key]

    # Fall back to humanized version
    case country_key
    when "europe"
      "Europe"
    when "usa"
      "United States"
    else
      country_key.humanize
    end
  end

  def self.get_metric_metadata(metric_name)
    case metric_name
    when "gdp_per_capita_ppp"
      {
        title: "GDP per capita, PPP",
        description: "GDP per capita based on purchasing power parity (PPP). PPP GDP is gross domestic product converted to international dollars using purchasing power parity rates.",
        unit: "$",
        format: "currency",
        higher_is_better: true,
        source: "Our World in Data - World Bank"
      }
    when "population"
      {
        title: "Population",
        description: "Total population by country and year.",
        unit: "people",
        format: "integer",
        higher_is_better: nil, # Neutral - neither good nor bad
        source: "Our World in Data"
      }
    when "child_mortality_rate"
      {
        title: "Child Mortality Rate",
        description: "Probability of dying between birth and exactly 5 years of age, expressed per 100 live births.",
        unit: "%",
        format: "percentage",
        decimals: 2,
        higher_is_better: false, # Lower is better for mortality
        source: "Our World in Data - UN IGME"
      }
    when "electricity_access"
      {
        title: "Access to Electricity",
        description: "Percentage of population with access to electricity.",
        unit: "%",
        format: "percentage",
        decimals: 2,
        higher_is_better: true, # Higher access is better
        source: "Our World in Data - World Bank"
      }
    when "life_expectancy"
      {
        title: "Life Expectancy",
        description: "Average number of years a newborn infant would live if current mortality patterns were to stay the same.",
        unit: "years",
        format: "decimal",
        decimals: 1,
        higher_is_better: true, # Higher life expectancy is better
        source: "Our World in Data - UN Population Division"
      }
    else
      {
        title: metric_name.humanize,
        description: "Data for #{metric_name.humanize}",
        unit: "",
        format: "integer",
        higher_is_better: true, # Default assumption
        source: "Our World in Data"
      }
    end
  end
end
