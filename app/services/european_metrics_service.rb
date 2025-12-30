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

  # Eurozone countries (20 countries using the Euro as of 2024)
  EUROZONE_COUNTRIES = [
    "germany", "france", "italy", "spain", "netherlands", "belgium", "austria",
    "ireland", "portugal", "greece", "finland", "slovakia", "slovenia", "estonia",
    "latvia", "lithuania", "luxembourg", "malta", "cyprus", "croatia"
  ].freeze

  # Non-Euro EU members (EU countries not using the Euro)
  NON_EURO_EU_COUNTRIES = [
    "poland", "sweden", "denmark", "czechia", "hungary", "romania", "bulgaria"
  ].freeze

  # Non-EU European countries
  NON_EU_EUROPE_COUNTRIES = [
    "united_kingdom", "switzerland", "norway", "iceland"
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

  # Minimum coverage threshold - require at least 30% of European population to have data (either current or forward-filled)
  MIN_COVERAGE_THRESHOLD = 0.3 # 30% of population

  # Threshold below which an aggregate is considered "incomplete" (shown with dotted line)
  # Based on population, not country count - ensures large countries like Germany, France, Russia are represented
  INCOMPLETE_THRESHOLD = 0.7 # 70% of population

  # Get metric value for a country/year, using forward-fill from most recent year if not available
  def self.get_metric_value_with_forward_fill(metric_name, country, year, country_data_cache = nil)
    # Try to get exact year data first
    if country_data_cache && country_data_cache[country]
      exact_value = country_data_cache[country][year]
      return { value: exact_value, year: year, forward_filled: false } if exact_value

      # Forward-fill: find most recent year before this one
      available_years = country_data_cache[country].keys.select { |y| y < year }.sort.reverse
      if available_years.any?
        fill_year = available_years.first
        return { value: country_data_cache[country][fill_year], year: fill_year, forward_filled: true }
      end
    else
      # Database lookup
      metric_record = get_metric_record(metric_name, country, year)
      return { value: metric_record.metric_value, year: year, forward_filled: false } if metric_record

      # Forward-fill: find most recent year before this one
      recent_record = Metric.for_metric(metric_name)
                           .for_country(country)
                           .where("year < ?", year)
                           .order(year: :desc)
                           .first
      if recent_record
        return { value: recent_record.metric_value, year: recent_record.year, forward_filled: true }
      end
    end

    nil
  end

  # Build a cache of all country data for a metric (for efficient forward-fill lookups)
  def self.build_country_data_cache(metric_name, countries)
    cache = {}
    countries.each do |country|
      data = Metric.for_metric(metric_name)
                  .for_country(country)
                  .pluck(:year, :metric_value)
                  .to_h
      cache[country] = data if data.any?
    end
    cache
  end

  # Calculate population-weighted average (for per capita metrics like GDP per capita)
  # Now uses forward-fill to maximize coverage and tracks actual vs effective coverage
  def self.calculate_population_weighted_average(metric_name, european_countries, options = {})
    requires_population = true

    # Get years with data
    metric_years = get_years_with_data(metric_name, european_countries)
    population_years = requires_population ? get_years_with_data("population", european_countries) : metric_years
    max_population_year = population_years.max

    # Build data caches for efficient forward-fill lookups
    metric_cache = build_country_data_cache(metric_name, european_countries)
    population_cache = build_country_data_cache("population", european_countries)

    stored_count = 0
    total_countries = european_countries.size

    Metric.transaction do
      # Process all years that have metric data
      metric_years.each do |year|
        total_weighted_value = 0.0
        total_population = 0.0
        countries_with_current_data = 0
        countries_with_forward_fill = 0

        # First pass: calculate total European population for coverage calculation
        total_european_population = 0.0
        european_countries.each do |country|
          pop_year = population_years.include?(year) ? year : max_population_year
          pop_record = get_metric_record("population", country, pop_year)
          next unless pop_record
          total_european_population += EuropeanCountriesHelper.european_population(country, pop_record.metric_value)
        end

        # Second pass: calculate weighted average and track population-based coverage
        population_with_current_data = 0.0
        population_with_any_data = 0.0

        european_countries.each do |country|
          # Get metric value (with forward-fill if needed)
          metric_result = get_metric_value_with_forward_fill(metric_name, country, year, metric_cache)
          next unless metric_result

          # Get population (with forward-fill if needed)
          pop_year = population_years.include?(year) ? year : max_population_year
          population_record = requires_population ? get_metric_record("population", country, pop_year) : nil
          next if requires_population && !population_record

          european_population = requires_population ?
            EuropeanCountriesHelper.european_population(country, population_record.metric_value) : 1.0

          # Metric value * population = weighted contribution
          weighted_value = metric_result[:value] * european_population
          total_weighted_value += weighted_value
          total_population += european_population

          # Track population-based coverage
          if metric_result[:forward_filled]
            countries_with_forward_fill += 1
            population_with_any_data += european_population
          else
            countries_with_current_data += 1
            population_with_current_data += european_population
            population_with_any_data += european_population
          end
        end

        contributing_countries = countries_with_current_data + countries_with_forward_fill

        # Calculate coverage metrics based on POPULATION, not country count
        # actual_coverage = proportion of population with data for this exact year
        # effective_coverage = proportion of population contributing (including forward-fill)
        actual_coverage = total_european_population > 0 ? population_with_current_data / total_european_population : 0.0
        effective_coverage = total_european_population > 0 ? population_with_any_data / total_european_population : 0.0

        # Skip years with insufficient effective coverage (based on population)
        if effective_coverage < MIN_COVERAGE_THRESHOLD
          puts "    ⚠️  Skipping #{year}: only #{(effective_coverage * 100).round(1)}% of population covered (< #{(MIN_COVERAGE_THRESHOLD * 100).round(0)}% threshold)"
          next
        end

        if total_population > 0
          europe_average = total_weighted_value / total_population
          pop_note = year > max_population_year ? " (using #{max_population_year} population weights)" : ""
          fill_note = countries_with_forward_fill > 0 ? "; #{countries_with_forward_fill} countries using forward-filled data" : ""
          description = "Population-weighted European average of #{metric_name.humanize} using country population weights#{pop_note}; adjusted for transcontinental populations; #{countries_with_current_data} countries with current data#{fill_note}."
          store_europe_metric(metric_name, year, europe_average, description, coverage: actual_coverage)
          stored_count += 1

          coverage_status = actual_coverage >= INCOMPLETE_THRESHOLD ? "complete" : "incomplete (#{(actual_coverage * 100).round(0)}% pop)"
          puts "    #{year}: #{europe_average.round(2)} [#{coverage_status}]"
        end
      end

      # Handle extrapolation for missing years if needed
      if requires_population
        stored_count += handle_extrapolation(metric_name, european_countries, metric_years, population_years, metric_years & population_years)
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
        description: latest_record.description,
        coverage: latest_record.coverage
      }
    else
      nil
    end
  end

  # Generic group aggregate calculator (e.g., EU27) with storage under target_key
  def self.calculate_group_aggregate(metric_name, country_keys:, target_key:, options: {})
    calculation_method = options[:method] || detect_calculation_method(metric_name)
    stored_count = 0
    total_countries = country_keys.size

    case calculation_method
    when :population_weighted, :population_weighted_rate
      # Get all years that have metric data
      metric_years = get_years_with_data(metric_name, country_keys)
      population_years = get_years_with_data("population", country_keys)
      max_population_year = population_years.max

      # Build data cache for forward-fill
      metric_cache = build_country_data_cache(metric_name, country_keys)

      Metric.transaction do
        metric_years.each do |year|
          total_weighted = 0.0
          total_pop = 0.0
          countries_with_current_data = 0
          countries_with_forward_fill = 0

          # First pass: calculate total group population for coverage calculation
          total_group_population = 0.0
          country_keys.each do |country|
            pop_year = population_years.include?(year) ? year : max_population_year
            pop_record = get_metric_record("population", country, pop_year)
            next unless pop_record
            total_group_population += EuropeanCountriesHelper.european_population(country, pop_record.metric_value)
          end

          # Second pass: calculate weighted average and track population-based coverage
          population_with_current_data = 0.0
          population_with_any_data = 0.0

          country_keys.each do |country|
            # Get metric value (with forward-fill if needed)
            metric_result = get_metric_value_with_forward_fill(metric_name, country, year, metric_cache)
            next unless metric_result

            # Use population for the year if available, otherwise use the most recent population
            pop_year = population_years.include?(year) ? year : max_population_year
            pop_record = get_metric_record("population", country, pop_year)
            next unless pop_record

            european_population = EuropeanCountriesHelper.european_population(country, pop_record.metric_value)
            total_weighted += metric_result[:value] * european_population
            total_pop += european_population

            if metric_result[:forward_filled]
              countries_with_forward_fill += 1
              population_with_any_data += european_population
            else
              countries_with_current_data += 1
              population_with_current_data += european_population
              population_with_any_data += european_population
            end
          end

          # Calculate coverage based on POPULATION, not country count
          actual_coverage = total_group_population > 0 ? population_with_current_data / total_group_population : 0.0
          effective_coverage = total_group_population > 0 ? population_with_any_data / total_group_population : 0.0

          # Skip years with insufficient effective coverage (based on population)
          if effective_coverage < MIN_COVERAGE_THRESHOLD
            puts "      ⚠️  Skipping #{target_key} #{year}: only #{(effective_coverage * 100).round(1)}% of population covered (< #{(MIN_COVERAGE_THRESHOLD * 100).round(0)}% threshold)"
            next
          end

          next if total_pop <= 0
          average = total_weighted / total_pop
          pop_note = year > max_population_year ? " (using #{max_population_year} population weights)" : ""
          fill_note = countries_with_forward_fill > 0 ? "; #{countries_with_forward_fill} using forward-filled data" : ""
          desc = "Population-weighted #{target_key.humanize} average of #{metric_name.humanize} using member populations#{pop_note}; #{countries_with_current_data} countries with current data#{fill_note}."
          store_group_metric(metric_name, target_key, year, average, desc, coverage: actual_coverage)
          stored_count += 1
        end
      end
    when :simple_sum
      years = get_years_with_data(metric_name, country_keys)
      metric_cache = build_country_data_cache(metric_name, country_keys)
      population_years = get_years_with_data("population", country_keys)
      max_population_year = population_years.max

      Metric.transaction do
        years.each do |year|
          sum = 0.0
          countries_with_current_data = 0
          countries_with_forward_fill = 0

          # First pass: calculate total group population for coverage calculation
          total_group_population = 0.0
          country_keys.each do |country|
            pop_year = population_years.include?(year) ? year : max_population_year
            pop_record = get_metric_record("population", country, pop_year)
            next unless pop_record
            total_group_population += EuropeanCountriesHelper.european_population(country, pop_record.metric_value)
          end

          # Second pass: calculate sum and track population-based coverage
          population_with_current_data = 0.0
          population_with_any_data = 0.0

          country_keys.each do |country|
            metric_result = get_metric_value_with_forward_fill(metric_name, country, year, metric_cache)
            next unless metric_result

            # Get population for coverage tracking
            pop_year = population_years.include?(year) ? year : max_population_year
            pop_record = get_metric_record("population", country, pop_year)
            country_population = pop_record ? EuropeanCountriesHelper.european_population(country, pop_record.metric_value) : 0.0

            value = if metric_name == "population"
              EuropeanCountriesHelper.european_population(country, metric_result[:value])
            else
              metric_result[:value] * EuropeanCountriesHelper.population_factor(country)
            end
            sum += value

            if metric_result[:forward_filled]
              countries_with_forward_fill += 1
              population_with_any_data += country_population
            else
              countries_with_current_data += 1
              population_with_current_data += country_population
              population_with_any_data += country_population
            end
          end

          # Calculate coverage based on POPULATION, not country count
          actual_coverage = total_group_population > 0 ? population_with_current_data / total_group_population : 0.0
          effective_coverage = total_group_population > 0 ? population_with_any_data / total_group_population : 0.0

          # Skip years with insufficient effective coverage (except for population which is more complete)
          if effective_coverage < MIN_COVERAGE_THRESHOLD && metric_name != "population"
            puts "      ⚠️  Skipping #{target_key} #{year}: only #{(effective_coverage * 100).round(1)}% of population covered (< #{(MIN_COVERAGE_THRESHOLD * 100).round(0)}% threshold)"
            next
          end

          fill_note = countries_with_forward_fill > 0 ? "; #{countries_with_forward_fill} using forward-filled data" : ""
          desc = metric_name == "population" ?
            "Total #{target_key.humanize} population (adjusted for transcontinental populations); #{countries_with_current_data} countries with current data#{fill_note}." :
            "Simple sum of #{metric_name.humanize} across #{target_key.humanize} members; #{countries_with_current_data} countries with current data#{fill_note}."
          store_group_metric(metric_name, target_key, year, sum, desc, coverage: actual_coverage)
          stored_count += 1
        end
      end
    else
      # Default: treat as population-weighted
      return calculate_group_aggregate(metric_name, country_keys: country_keys, target_key: target_key, options: { method: :population_weighted })
    end

    stored_count
  end

  # Calculate all regional aggregates (EU-27, Eurozone, Non-Euro EU, Non-EU Europe) for a metric
  def self.calculate_all_regional_aggregates(metric_name, options: {})
    results = {}

    puts "Calculating regional aggregates for #{metric_name}..."

    # EU-27
    puts "  → EU-27 aggregate..."
    results[:european_union] = calculate_group_aggregate(
      metric_name,
      country_keys: EU27_COUNTRIES,
      target_key: "european_union",
      options: options
    )

    # Eurozone
    puts "  → Eurozone aggregate..."
    results[:eurozone] = calculate_group_aggregate(
      metric_name,
      country_keys: EUROZONE_COUNTRIES,
      target_key: "eurozone",
      options: options
    )

    # Non-Euro EU
    puts "  → Non-Euro EU aggregate..."
    results[:non_euro_eu] = calculate_group_aggregate(
      metric_name,
      country_keys: NON_EURO_EU_COUNTRIES,
      target_key: "non_euro_eu",
      options: options
    )

    # Non-EU Europe (only if data available)
    non_eu_with_data = NON_EU_EUROPE_COUNTRIES.select do |country|
      Metric.where(metric_name: metric_name, country: country).exists?
    end

    if non_eu_with_data.any?
      puts "  → Non-EU Europe aggregate (#{non_eu_with_data.size} countries)..."
      results[:non_eu_europe] = calculate_group_aggregate(
        metric_name,
        country_keys: non_eu_with_data,
        target_key: "non_eu_europe",
        options: options
      )
    end

    puts "✅ Completed regional aggregates for #{metric_name}"
    results
  end

  # Calculate all regional aggregates for all metrics that have Europe data
  def self.calculate_all_regional_aggregates_for_all_metrics(options: {})
    # Find all metrics that have a Europe aggregate
    metrics_with_europe = Metric.where(country: "europe").distinct.pluck(:metric_name)

    puts "Found #{metrics_with_europe.size} metrics with Europe aggregate"
    puts ""

    results = {}
    metrics_with_europe.each do |metric_name|
      results[metric_name] = calculate_all_regional_aggregates(metric_name, options: options)
      puts ""
    end

    results
  end

  def self.store_group_metric(metric_name, country_key, year, value, description = nil, coverage: nil)
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
      coverage: coverage,
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

  def self.store_europe_metric(metric_name, year, value, description = nil, source_unit: nil, coverage: nil)
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
      coverage: coverage,
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
    total_countries = european_countries.size

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

        # Only create aggregate if we have enough coverage (using same threshold as main calculation)
        coverage = contributing_countries.to_f / total_countries
        if coverage < MIN_COVERAGE_THRESHOLD
          puts "    ⚠️  Skipping extrapolation for #{year}: only #{contributing_countries}/#{total_countries} countries (#{(coverage * 100).round(1)}% < #{(MIN_COVERAGE_THRESHOLD * 100).round(0)}% threshold)"
          next
        end

        if total_population > 0
          europe_average = total_weighted_value / total_population
          description = "Population-weighted European average of #{metric_name.humanize} using #{latest_pop_year} population weights (extrapolated); adjusted for transcontinental populations; #{contributing_countries} contributing countries."
          store_europe_metric(metric_name, year, europe_average, description)
          stored_count += 1
        end
      end
    end

    stored_count
  end

  # Public method to get latest values for any metric
  def self.latest_metric_for_countries(metric_name, country_keys = nil)
    country_keys ||= EuropeanCountriesHelper.all_european_countries + [ "europe", "usa", "china", "india" ]
    Rails.logger.debug "EuropeanMetricsService#latest_metric_for_countries - metric_name: #{metric_name}, country_keys: #{country_keys.inspect}"

    result = {}

    country_keys.each do |country|
      Rails.logger.debug "EuropeanMetricsService - Processing country: #{country}"
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

      Rails.logger.debug "EuropeanMetricsService - Latest record for #{country}: #{latest_record.inspect}"

      if latest_record
        result[country] = {
          value: latest_record.metric_value,
          year: latest_record.year
        }
        Rails.logger.debug "EuropeanMetricsService - Added to result for #{country}: #{result[country].inspect}"
      else
        Rails.logger.debug "EuropeanMetricsService - No record found for #{country}"
      end
    end

    Rails.logger.debug "EuropeanMetricsService#latest_metric_for_countries - Final result: #{result.inspect}"
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

    # Aggregate country keys for coverage lookup
    aggregate_countries = [ "europe", "european_union", "eurozone", "non_euro_eu", "non_eu_europe" ]

    # Get countries data
    countries_data = {}

    # Process all requested countries
    requested_countries.each do |country_key|
      if available_countries.include?(country_key)
        # Country has direct database records - get data and coverage info
        records = Metric.for_metric(metric_name)
                       .for_country(country_key)
                       .where(year: start_year..end_year)
                       .order(:year)

        country_data = records.pluck(:year, :metric_value).to_h

        # For aggregates, also get coverage info
        coverage_data = {}
        if aggregate_countries.include?(country_key)
          records.pluck(:year, :coverage).each do |year, cov|
            coverage_data[year] = cov if cov.present?
          end
        end

        # Get human-readable name
        name = get_country_display_name(country_key)

        countries_data[country_key] = {
          name: name,
          data: country_data,
          coverage: coverage_data.any? ? coverage_data : nil,
          is_aggregate: aggregate_countries.include?(country_key)
        }.compact
      elsif country_key == "europe" && available_countries.any? { |c| EU_COUNTRIES.include?(c) }
        # Calculate Europe aggregate on-the-fly if not stored (fallback)
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
          data: europe_data,
          is_aggregate: true
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
    # Handle regional aggregates first
    case country_key
    when "europe"
      return "Europe"
    when "european_union"
      return "EU-27"
    when "eurozone"
      return "Eurozone"
    when "non_euro_eu"
      return "Non-€ EU"
    when "non_eu_europe"
      return "Non-EU Europe"
    when "usa"
      return "United States"
    end

    # Use OurWorldInDataService mapping (most comprehensive)
    owid_mapping = OurWorldInDataService::COUNTRIES.invert
    return owid_mapping[country_key] if owid_mapping[country_key]

    # Try population service mapping as fallback
    pop_mapping = PopulationDataService::COUNTRIES.invert
    return pop_mapping[country_key] if pop_mapping[country_key]

    # Fall back to humanized version
    country_key.humanize
  end

  def self.get_metric_metadata(metric_name)
    # First try to get metadata from config/metrics.yml
    config = load_metrics_config[metric_name]

    if config
      {
        title: metric_name.humanize.titleize,
        description: config["description"],
        unit: config["unit"] || "",
        format: detect_format(config["unit"]),
        higher_is_better: detect_higher_is_better(metric_name),
        source: detect_source(config["source"])
      }
    else
      # Fall back to hardcoded metadata for known metrics
      hardcoded_metadata(metric_name)
    end
  end

  def self.load_metrics_config
    @metrics_config ||= begin
      config_path = Rails.root.join("config", "metrics.yml")
      if File.exist?(config_path)
        YAML.load_file(config_path) || {}
      else
        {}
      end
    end
  end

  def self.detect_format(unit)
    case unit
    when /\$/, /dollar/i, /currency/i then "currency"
    when /%/ then "percentage"
    when /year/i then "decimal"
    when /people/i, /person/i then "integer"
    when /score/i then "decimal"
    else "decimal"
    end
  end

  def self.detect_higher_is_better(metric_name)
    # Metrics where lower is better
    lower_is_better = %w[
      child_mortality_rate homicide_rate death_rate infant_mortality
      poverty_rate unemployment_rate
    ]
    # Metrics that are neutral
    neutral = %w[population fertility_rate]

    if lower_is_better.include?(metric_name)
      false
    elsif neutral.include?(metric_name)
      nil
    else
      true
    end
  end

  def self.detect_source(source_config)
    case source_config
    when "owid" then "Our World in Data"
    when "ilo" then "International Labour Organization"
    else "Our World in Data"
    end
  end

  def self.hardcoded_metadata(metric_name)
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
        higher_is_better: nil,
        source: "Our World in Data"
      }
    when "child_mortality_rate"
      {
        title: "Child Mortality Rate",
        description: "Probability of dying between birth and exactly 5 years of age, expressed per 100 live births.",
        unit: "%",
        format: "percentage",
        decimals: 2,
        higher_is_better: false,
        source: "Our World in Data - UN IGME"
      }
    when "electricity_access"
      {
        title: "Access to Electricity",
        description: "Percentage of population with access to electricity.",
        unit: "%",
        format: "percentage",
        decimals: 2,
        higher_is_better: true,
        source: "Our World in Data - World Bank"
      }
    when "life_expectancy"
      {
        title: "Life Expectancy",
        description: "Average number of years a newborn infant would live if current mortality patterns were to stay the same.",
        unit: "years",
        format: "decimal",
        decimals: 1,
        higher_is_better: true,
        source: "Our World in Data - UN Population Division"
      }
    else
      # Try to get description from database as last resort
      db_record = Metric.where(metric_name: metric_name).first
      {
        title: metric_name.humanize.titleize,
        description: db_record&.description || "Data for #{metric_name.humanize}",
        unit: db_record&.unit || "",
        format: "decimal",
        higher_is_better: true,
        source: db_record&.source || "Our World in Data"
      }
    end
  end
end
