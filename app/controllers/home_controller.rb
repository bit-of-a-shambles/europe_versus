class HomeController < ApplicationController
  def index
    # Prevent caching to ensure fresh data
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"

    # Only fetch metrics that exist in the database
    @gdp_data = fetch_latest_gdp_data
    @population_data = fetch_latest_population_data
    @child_mortality_data = fetch_latest_child_mortality_data
    @electricity_access_data = fetch_latest_electricity_access_data
  end

  def methodology
    # Prevent caching to ensure fresh data
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"

    # Fetch all current metrics with Europe data
    @gdp_data = fetch_detailed_gdp_data
    @population_data = fetch_detailed_population_data
    @child_mortality_data = fetch_detailed_child_mortality_data
    @electricity_access_data = fetch_detailed_electricity_access_data

    # Get list of all European countries with their population data
    @european_countries = EuropeanCountriesHelper.all_european_countries
    @european_countries_with_population = fetch_european_countries_with_population

    # Compute data coverage for transparency (which countries have both GDP and population)
    compute_data_coverage
  end

  private

  # Helper to convert string keys to symbols and add europe fallback from european_union
  def normalize_metric_data(data)
    return nil if data.nil? || data.empty?

    result = data.transform_keys(&:to_sym)

    # If 'europe' is missing, try to use 'european_union' as fallback
    if !result.key?(:europe) && result.key?(:european_union)
      result[:europe] = result[:european_union]
    end

    result
  end

  def fetch_latest_gdp_data
    # Get latest GDP data for key countries using EuropeanMetricsService
    key_countries = [ "europe", "european_union", "usa", "india", "china" ]
    latest_data = EuropeanMetricsService.latest_metric_for_countries("gdp_per_capita_ppp", key_countries)

    {
      countries: normalize_metric_data(latest_data),
      year: latest_data.values.first&.dig(:year) || 2024
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch GDP data: #{e.message}"
    { error: true }
  end

  def fetch_latest_population_data
    # Get all European countries' latest population data plus comparison countries
    european_countries = EuropeanCountriesHelper.all_european_countries
    all_data = PopulationDataService.latest_population_for_countries(
      european_countries + [ "european_union", "usa", "india", "china" ]
    )

    # Calculate Europe's total population by summing individual country populations
    # Apply population factors for transcontinental countries (Russia, Turkey, Azerbaijan)
    europe_total = 0
    europe_year = Date.current.year
    european_countries.each do |country|
      if all_data[country]
        raw_pop = all_data[country][:value].to_i
        factor = EuropeanCountriesHelper.population_factor(country)
        europe_total += (raw_pop * factor).round
        europe_year = all_data[country][:year] if all_data[country][:year]
      end
    end

    # Add calculated Europe aggregate to the data
    all_data["europe"] = { value: europe_total, year: europe_year }

    {
      countries: normalize_metric_data(all_data),
      year: europe_year
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch population data: #{e.message}"
    { error: true }
  end

  def fetch_latest_child_mortality_data
    # Get latest child mortality data for key countries using EuropeanMetricsService
    key_countries = [ "europe", "european_union", "usa", "india", "china" ]
    latest_data = EuropeanMetricsService.latest_metric_for_countries("child_mortality_rate", key_countries)

    {
      countries: normalize_metric_data(latest_data),
      year: latest_data.values.first&.dig(:year) || 2024
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch child mortality data: #{e.message}"
    { error: true }
  end

  def fetch_latest_electricity_access_data
    # Get latest electricity access data for key countries using EuropeanMetricsService
    key_countries = [ "europe", "european_union", "usa", "india", "china" ]
    latest_data = EuropeanMetricsService.latest_metric_for_countries("electricity_access", key_countries)

    {
      countries: normalize_metric_data(latest_data),
      year: latest_data.values.first&.dig(:year) || 2024
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch electricity access data: #{e.message}"
    { error: true }
  end

  def fetch_detailed_gdp_data
    # Get all European countries' latest GDP data using EuropeanMetricsService
    european_countries = EuropeanCountriesHelper.all_european_countries
    all_data = EuropeanMetricsService.latest_metric_for_countries("gdp_per_capita_ppp", european_countries + [ "europe", "usa", "india", "china" ])

    # Calculate Europe aggregate if not present
    europe_total_gdp = 0
    europe_total_population = 0
    year = nil

    if all_data["europe"].nil?
      european_countries.each do |country|
        next unless all_data[country]

        country_gdp = all_data[country][:value]
        country_population = PopulationDataService.latest_population_for_countries([ country ])[country]&.dig(:value)

        if country_gdp && country_population
          europe_total_gdp += country_gdp * country_population
          europe_total_population += country_population
          year ||= all_data[country][:year]
        end
      end

      if europe_total_population > 0
        all_data["europe"] = {
          value: (europe_total_gdp / europe_total_population).round(2),
          year: year,
          calculated: true
        }
      end
    else
      # If Europe data exists, calculate the weighted GDP for display purposes
      european_countries.each do |country|
        next unless all_data[country]

        country_gdp = all_data[country][:value]
        country_population = PopulationDataService.latest_population_for_countries([ country ])[country]&.dig(:value)

        if country_gdp && country_population
          europe_total_gdp += country_gdp * country_population
          europe_total_population += country_population
        end
      end
    end

    {
      countries: all_data,
      european_countries: european_countries,
      year: all_data["europe"]&.dig(:year) || 2024,
      total_weighted_gdp: europe_total_gdp
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch detailed GDP data: #{e.message}"
    { error: true }
  end

  def fetch_detailed_population_data
    # Get all European countries' latest population data
    european_countries = EuropeanCountriesHelper.all_european_countries
    all_data = PopulationDataService.latest_population_for_countries(european_countries + [ "usa", "india", "china" ])

    # Calculate Europe's total population by summing individual country populations
    # Apply population factors for transcontinental countries (Russia, Turkey, Azerbaijan)
    europe_total = 0
    europe_year = Date.current.year
    european_countries.each do |country|
      if all_data[country]
        raw_pop = all_data[country][:value].to_i
        factor = EuropeanCountriesHelper.population_factor(country)
        europe_total += (raw_pop * factor).round
        europe_year = all_data[country][:year] if all_data[country][:year]
      end
    end

    # Add calculated Europe aggregate to the data
    all_data["europe"] = { value: europe_total, year: europe_year }

    {
      countries: all_data,
      european_countries: european_countries,
      year: europe_year
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch detailed population data: #{e.message}"
    { error: true }
  end

  def fetch_detailed_child_mortality_data
    # Get all available countries' latest child mortality data using EuropeanMetricsService
    key_countries = [ "europe", "usa", "india", "china" ]
    latest_data = EuropeanMetricsService.latest_metric_for_countries("child_mortality_rate", key_countries)

    {
      countries: latest_data,
      year: latest_data.values.first&.dig(:year) || 2024
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch detailed child mortality data: #{e.message}"
    { error: true }
  end

  def fetch_detailed_electricity_access_data
    # Get all available countries' latest electricity access data using EuropeanMetricsService
    key_countries = [ "europe", "usa", "india", "china" ]
    latest_data = EuropeanMetricsService.latest_metric_for_countries("electricity_access", key_countries)

    {
      countries: latest_data,
      year: latest_data.values.first&.dig(:year) || 2024
    }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch detailed electricity access data: #{e.message}"
    { error: true }
  end

  def fetch_european_countries_with_population
    # Get all European country keys (returns an array)
    european_country_keys = EuropeanCountriesHelper.all_european_countries

    # Fetch latest population data for all European countries
    population_data = PopulationDataService.latest_population_for_countries(european_country_keys)

    # Calculate Europe's total population by summing individual country populations
    # Apply population factors for transcontinental countries (Russia, Turkey, Azerbaijan)
    europe_total = european_country_keys.sum do |country_key|
      raw_pop = population_data[country_key]&.dig(:value).to_i
      factor = EuropeanCountriesHelper.population_factor(country_key)
      (raw_pop * factor).round
    end

    # Build array with country data including percentages
    countries_with_data = european_country_keys.map do |country_key|
      country_name = EuropeanCountriesHelper.country_name(country_key)
      raw_population = population_data[country_key]&.dig(:value) || 0
      # Apply population factor for transcontinental countries
      factor = EuropeanCountriesHelper.population_factor(country_key)
      adjusted_population = (raw_population * factor).round
      percentage = europe_total > 0 ? (adjusted_population.to_f / europe_total * 100).round(2) : 0

      {
        key: country_key,
        name: country_name,
        population: adjusted_population,
        percentage: percentage
      }
    end

    # Filter out countries with no population data and sort by population descending
    countries_with_data.select { |c| c[:population] > 0 }.sort_by { |c| -c[:population] }
  rescue StandardError => e
    Rails.logger.error "Failed to fetch European countries with population: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    []
  end

  # Build coverage info showing how many countries have both GDP and population data
  def compute_data_coverage
    european_country_keys = @european_countries || EuropeanCountriesHelper.all_european_countries
    gdp_countries = (@gdp_data && @gdp_data[:countries]) ? @gdp_data[:countries].keys : []
    pop_countries = (@population_data && @population_data[:countries]) ? @population_data[:countries].keys : []

    # Filter to only European countries (exclude aggregates like 'europe', 'usa', etc.)
    european_gdp = european_country_keys.select { |c| gdp_countries.include?(c) }
    european_pop = european_country_keys.select { |c| pop_countries.include?(c) }

    both = european_country_keys.select { |c| european_gdp.include?(c) && european_pop.include?(c) }
    missing_gdp = european_country_keys.select { |c| !european_gdp.include?(c) && european_pop.include?(c) }
    missing_population = european_country_keys.select { |c| !european_pop.include?(c) && european_gdp.include?(c) }
    missing_both = european_country_keys.select { |c| !european_gdp.include?(c) && !european_pop.include?(c) }

    @coverage = {
      total_european_countries: european_country_keys.size,
      with_both: both,
      missing_gdp: missing_gdp,
      missing_population: missing_population,
      missing_both: missing_both
    }
  rescue StandardError => e
    Rails.logger.error "Failed to compute data coverage: #{e.message}"
    @coverage = nil
  end
end
