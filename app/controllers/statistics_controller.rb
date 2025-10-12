require 'ostruct'

class StatisticsController < ApplicationController
  def index
    # Get all unique metric names and group them by category
    @statistics = group_metrics_by_category
  end

  def show
    @metric_name = params[:id]
    @metric_data = get_metric_comparison(@metric_name)
    
    if @metric_data.empty?
      redirect_to statistics_path, alert: "Metric not found"
      return
    end
    
    # Create a statistic-like object for view compatibility
    @statistic = create_statistic_like_object(@metric_name)
  end
  
  def chart
    # Extract chart name from the request path
    # Remove /statistics/ prefix if present
    chart_name = request.path.sub(/^\/statistics\//, '').sub(/^\//, '')
    
    if chart_name == 'population'
      # Use local population data from our database
      @chart_data = build_population_chart_data
      @chart_name = 'population'
    elsif chart_name == 'gdp-per-capita-ppp' || chart_name == 'gdp-per-capita-worldbank'
      # Use local GDP data from our database - pass nil to get all available countries
      @chart_data = GdpDataService.build_gdp_chart_data(nil)
      @chart_name = 'gdp-per-capita-worldbank'
    elsif chart_name == 'child-mortality-rate'
      # Use local child mortality data from our database
      @chart_data = build_metric_chart_data('child_mortality_rate', 'Child Mortality Rate', '% of children')
      @chart_name = 'child-mortality-rate'
    elsif chart_name == 'electricity-access'
      # Use local electricity access data from our database
      @chart_data = build_metric_chart_data('electricity_access', 'Access to Electricity', '% of population')
      @chart_name = 'share-of-the-population-with-access-to-electricity'
    else
      # Use Our World in Data for other charts
      @chart_data = OurWorldInDataService.fetch_chart_data(chart_name, start_year: 2000, end_year: 2024)
      @chart_name = chart_name
    end
    
    Rails.logger.info "CHART DEBUG - Chart name: #{chart_name}"
    Rails.logger.info "CHART DEBUG - @chart_data keys: #{@chart_data&.keys&.inspect}"
    Rails.logger.info "CHART DEBUG - @chart_data[:countries] keys: #{@chart_data&.dig(:countries)&.keys&.inspect}"
    Rails.logger.info "CHART DEBUG - Sample country data (europe): #{@chart_data&.dig(:countries, 'europe')&.inspect}"
    Rails.logger.info "CHART DEBUG - Sample country data (usa): #{@chart_data&.dig(:countries, 'usa')&.inspect}"
    
    # Render the generic chart template
    render 'chart'
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
    years = Metric.for_metric('population')
                  .where(year: start_year..end_year)
                  .distinct
                  .pluck(:year)
                  .sort
    
    # Get countries data
    countries_data = {}
    
    # Country mapping from PopulationDataService
    country_mapping = PopulationDataService::COUNTRIES.invert
    
    country_mapping.each do |country_key, owid_name|
      country_data = Metric.for_metric('population')
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
    europe_data = Metric.for_metric('population')
                       .for_country('europe')
                       .where(year: start_year..end_year)
                       .order(:year)
                       .pluck(:year, :metric_value)
                       .to_h
    
    countries_data['europe'] = {
      name: 'Europe',
      data: europe_data
    }
    
    {
      metadata: {
        title: 'Population',
        description: 'Total population by country',
        unit: 'people',
        source: 'Our World in Data'
      },
      years: years,
      countries: countries_data
    }
  end
  
  def group_metrics_by_category
    # Define category mappings for metrics
    category_mappings = {
      'economy' => ['gdp_per_capita_ppp', 'gni_per_capita', 'unemployment_rate'],
      'social' => ['population', 'life_expectancy', 'birth_rate', 'death_rate'],
      'development' => ['child_mortality_rate', 'electricity_access'],
      'environment' => ['co2_emissions', 'renewable_energy', 'forest_area'],
      'innovation' => ['research_development', 'patents', 'internet_users']
    }
    
    # Get all unique metric names that have data
    available_metrics = Metric.select(:metric_name).distinct.pluck(:metric_name)
    
    # Group available metrics by category
    grouped = {}
    category_mappings.each do |category, metric_names|
      category_metrics = metric_names & available_metrics
      unless category_metrics.empty?
        grouped[category] = category_metrics.map { |metric_name| 
          create_statistic_like_object(metric_name) 
        }.compact
      end
    end
    
    grouped
  end

  def create_statistic_like_object(metric_name)
    # Get latest data for this metric across all countries
    latest_metrics = Metric.latest_for_metric(metric_name)
    
    return nil if latest_metrics.empty?
    
    # Group by country
    by_country = latest_metrics.index_by(&:country)
    
    # Use stored Europe aggregate; if missing, compute using EuropeanMetricsService (population-weighted where applicable)
    europe_value = by_country['europe']&.metric_value
    europe_unit = by_country['europe']&.unit
    if europe_value.nil?
      EuropeanMetricsService.calculate_europe_aggregate(metric_name)
      europe_record = Metric.latest_for_country_and_metric('europe', metric_name)
      if europe_record
        europe_value = europe_record.metric_value
        europe_unit = europe_record.unit
      else
        europe_value = calculate_european_average_for_metric(metric_name, latest_metrics)
      end
    end
    
    # Create a statistic-like object for view compatibility
    # Prefer Europe's aggregate description if available
    europe_desc = Metric.latest_for_country_and_metric('europe', metric_name)&.description

    OpenStruct.new(
      metric: latest_metrics.first.metric_display_name,
      europe_value: europe_value || 0,
      us_value: by_country['usa']&.metric_value || 0,
      india_value: by_country['india']&.metric_value || 0,
      china_value: by_country['china']&.metric_value || 0,
      unit: europe_unit || latest_metrics.first.unit,
      year: latest_metrics.first.year,
      description: europe_desc || latest_metrics.first.description,
      source: latest_metrics.first.source,
      id: metric_name # Use metric_name as ID for URLs
    )
  end
  
  def calculate_european_average_for_metric(metric_name, latest_metrics)
    # Major EU countries for averaging
    eu_countries = ['germany', 'france', 'italy', 'spain', 'netherlands', 'poland', 'sweden', 'denmark', 'finland', 'austria', 'belgium']
    
    # Get values for EU countries from the provided metrics
    eu_values = latest_metrics.select { |metric| eu_countries.include?(metric.country) }
                               .map(&:metric_value)
                               .compact
    
    return nil if eu_values.empty?
    
    eu_values.sum / eu_values.count
  end

  def get_metric_comparison(metric_name)
    Metric.latest_for_metric(metric_name).index_by(&:country)
  end
end
