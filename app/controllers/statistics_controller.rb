require "ostruct"

class StatisticsController < ApplicationController
  def index
    # Get all unique metric names and group them by category
    @statistics = group_metrics_by_category
  end

  def show
    # Get the metric name from params
    id = params[:id]

    # If the URL contains underscores, redirect to hyphenated version
    if id.include?("_")
      redirect_to statistic_path(id.tr("_", "-")), status: :moved_permanently
      return
    end

    # Convert hyphens to underscores for database lookup
    @metric_name = id.tr("-", "_")
    chart_name = id # Keep hyphenated version for OWID URLs

    # Build chart data based on metric name
    if chart_name == "population"
      # Use local population data from our database
      @chart_data = build_population_chart_data
      @chart_name = "population"
    elsif chart_name == "gdp-per-capita-ppp" || chart_name == "gdp-per-capita-worldbank"
      # Use local GDP data from our database via EuropeanMetricsService
      @chart_data = EuropeanMetricsService.build_metric_chart_data("gdp_per_capita_ppp")
      @chart_name = "gdp-per-capita-worldbank"
    elsif chart_name == "child-mortality-rate"
      # Use local child mortality data from our database
      @chart_data = build_metric_chart_data("child_mortality_rate", "Child Mortality Rate", "% of children")
      @chart_name = "child-mortality"
    elsif chart_name == "electricity-access"
      # Use local electricity access data from our database
      @chart_data = build_metric_chart_data("electricity_access", "Access to Electricity", "% of population")
      @chart_name = "share-of-the-population-with-access-to-electricity"
    elsif chart_name == "health-expenditure-gdp-percent"
      # Use local health expenditure data from our database
      @chart_data = build_metric_chart_data("health_expenditure_gdp_percent", "Health Expenditure", "% of GDP")
      @chart_name = "total-healthcare-expenditure-gdp"
    elsif chart_name == "life-satisfaction"
      # Use local life satisfaction data from our database
      @chart_data = build_metric_chart_data("life_satisfaction", "Life Satisfaction", "score (0-10)")
      @chart_name = "happiness-cantril-ladder"
    else
      # Use Our World in Data for other charts
      @chart_data = OurWorldInDataService.fetch_chart_data(chart_name, start_year: 2000, end_year: 2024)
      @chart_name = chart_name
    end

    Rails.logger.info "CHART DEBUG - Metric name: #{@metric_name}, Chart name: #{chart_name}"
    Rails.logger.info "CHART DEBUG - @chart_data keys: #{@chart_data&.keys&.inspect}"
    Rails.logger.info "CHART DEBUG - @chart_data[:countries] keys: #{@chart_data&.dig(:countries)&.keys&.inspect}"
    Rails.logger.info "CHART DEBUG - Sample country data (europe): #{@chart_data&.dig(:countries, 'europe')&.inspect}"
    Rails.logger.info "CHART DEBUG - Sample country data (usa): #{@chart_data&.dig(:countries, 'usa')&.inspect}"

    # Render the chart template (was previously named chart.html.erb)
    render "chart"
  end

  private

  def build_metric_chart_data(metric_name, title, unit)
    # Use EuropeanMetricsService which handles Europe aggregates
    EuropeanMetricsService.build_metric_chart_data(metric_name, {
      title: title,
      unit: unit,
      start_year: 2000,
      end_year: 2024
    })
  end

  def build_population_chart_data
    # Get population data from our database
    start_year = 2000
    end_year = 2024

    # Get all available years in range
    years = Metric.for_metric("population")
                  .where(year: start_year..end_year)
                  .distinct
                  .pluck(:year)
                  .sort

    # Get countries data
    countries_data = {}

    # Country mapping from PopulationDataService
    country_mapping = PopulationDataService::COUNTRIES.invert

    country_mapping.each do |country_key, owid_name|
      country_data = Metric.for_metric("population")
                          .for_country(country_key)
                          .where(year: start_year..end_year)
                          .order(:year)
                          .pluck(:year, :metric_value)
                          .to_h

      countries_data[country_key] = {
        name: owid_name,
        data: country_data
      }
    end

    # Add Europe aggregate data
    europe_data = Metric.for_metric("population")
                       .for_country("europe")
                       .where(year: start_year..end_year)
                       .order(:year)
                       .pluck(:year, :metric_value)
                       .to_h

    countries_data["europe"] = {
      name: "Europe",
      data: europe_data
    }

    {
      metadata: {
        title: "Population",
        description: "Total population by country",
        unit: "people",
        source: "Our World in Data"
      },
      years: years,
      countries: countries_data
    }
  end

  def group_metrics_by_category
    # Get category mappings from OWID config (if available) plus hardcoded ones
    owid_category_map = {}
    if defined?(OwidMetricImporter)
      OwidMetricImporter.all_configs.each do |metric_name, config|
        category = config[:category] || "social"
        owid_category_map[category] ||= []
        owid_category_map[category] << metric_name
      end
    end

    # Hardcoded category mappings for non-OWID metrics
    hardcoded_mappings = {
      "economy" => [ "gdp_per_capita_ppp", "gni_per_capita", "unemployment_rate" ],
      "social" => [ "population", "life_expectancy", "birth_rate", "death_rate" ],
      "development" => [ "child_mortality_rate", "electricity_access" ],
      "environment" => [ "co2_emissions", "renewable_energy", "forest_area" ],
      "innovation" => [ "research_development", "patents", "internet_users" ]
    }

    # Merge OWID and hardcoded mappings
    category_mappings = hardcoded_mappings.merge(owid_category_map) do |key, hardcoded, owid|
      (hardcoded + owid).uniq
    end

    # Get all unique metric names that have data
    available_metrics = Metric.select(:metric_name).distinct.pluck(:metric_name)

    # Group available metrics by category - create simple stat objects for index view
    grouped = {}
    category_mappings.each do |category, metric_names|
      category_metrics = metric_names & available_metrics
      unless category_metrics.empty?
        grouped[category] = category_metrics.map { |metric_name|
          create_stat_summary(metric_name)
        }.compact
      end
    end

    grouped
  end

  def create_stat_summary(metric_name)
    # Get latest data for this metric
    latest_metrics = Metric.latest_for_metric(metric_name)
    return nil if latest_metrics.empty?

    # Group by country
    by_country = latest_metrics.index_by(&:country)

    # Get Europe aggregate
    europe_record = by_country["europe"]
    europe_value = europe_record&.metric_value || 0
    europe_unit = europe_record&.unit || latest_metrics.first.unit

    # Create simple struct for index view
    OpenStruct.new(
      id: metric_name.tr("_", "-"), # Use hyphenated version for URLs
      metric: latest_metrics.first.metric_display_name,
      europe_value: europe_value,
      us_value: by_country["usa"]&.metric_value || 0,
      india_value: by_country["india"]&.metric_value || 0,
      china_value: by_country["china"]&.metric_value || 0,
      unit: europe_unit,
      year: latest_metrics.first.year,
      description: europe_record&.description || latest_metrics.first.description
    )
  end
end
