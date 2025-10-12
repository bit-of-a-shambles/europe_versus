class DevelopmentDataService < OurWorldInDataService
  
  def self.fetch_and_store_child_mortality
    Rails.logger.info "Fetching child mortality data from OWID..."
    result = fetch_chart_data('child-mortality', start_year: 2000, end_year: 2024)
    
    return result if result[:error]
    
  store_metric_data(result, 'child_mortality_rate')
  calculate_and_store_europe_aggregate('child_mortality_rate')
  # Ensure EU27 aggregate exists
  EuropeanMetricsService.calculate_group_aggregate('child_mortality_rate', country_keys: EuropeanMetricsService::EU27_COUNTRIES, target_key: 'european_union')
    Rails.logger.info "Successfully stored child mortality data"
    result
  end
  
  def self.fetch_and_store_electricity_access
    Rails.logger.info "Fetching electricity access data from OWID..."
    result = fetch_chart_data('share-of-the-population-with-access-to-electricity', start_year: 2000, end_year: 2024)
    
    return result if result[:error]
    
  store_metric_data(result, 'electricity_access')
  calculate_and_store_europe_aggregate('electricity_access')
  # Ensure EU27 aggregate exists
  EuropeanMetricsService.calculate_group_aggregate('electricity_access', country_keys: EuropeanMetricsService::EU27_COUNTRIES, target_key: 'european_union')
    Rails.logger.info "Successfully stored electricity access data"
    result
  end
  
  # Get latest data from database
  def self.latest_child_mortality_for_countries(countries: COUNTRIES.keys)
    get_latest_metric_data('child_mortality_rate', countries)
  end
  
  def self.latest_electricity_access_for_countries(countries: COUNTRIES.keys)
    get_latest_metric_data('electricity_access', countries)
  end
  
  private
  
  def self.store_metric_data(result, metric_name)
    return unless result[:countries]
    
    result[:countries].each do |country_key, country_data|
      next unless country_data[:data]
      
      country_name = COUNTRIES[country_key] || country_key
      
      country_data[:data].each do |year, value|
        next if value.nil? || value == 0
        
        metric = Metric.find_or_initialize_by(
          country: country_key,
          metric_name: metric_name,
          year: year
        )
        
        metric.assign_attributes(
          metric_value: value,
          unit: result.dig(:metadata, :unit) || '%',
          source: result.dig(:metadata, :source) || 'Our World in Data',
          description: result.dig(:metadata, :description)
        )
        
        if metric.save
          Rails.logger.info "Saved #{metric_name} for #{country_name} (#{year}): #{value}"
        else
          Rails.logger.error "Failed to save #{metric_name} for #{country_name}: #{metric.errors.full_messages}"
        end
      end
    end
  end
  
  def self.get_latest_metric_data(metric_name, countries)
    countries_data = {}
    
    countries.each do |country_key|
      if country_key == 'europe'
        # Prefer stored Europe aggregate; compute via EuropeanMetricsService if missing
        latest_metric = Metric.latest_for_country_and_metric('europe', metric_name)
        unless latest_metric
          EuropeanMetricsService.calculate_europe_aggregate(metric_name)
          latest_metric = Metric.latest_for_country_and_metric('europe', metric_name)
        end
        if latest_metric
          countries_data[country_key] = {
            name: 'Europe',
            value: latest_metric.metric_value.to_f,
            year: latest_metric.year
          }
        end
      else
        latest_metric = Metric.latest_for_country_and_metric(country_key, metric_name)
        
        if latest_metric
          countries_data[country_key] = {
            name: COUNTRIES[country_key] || country_key.humanize,
            value: latest_metric.metric_value.to_f,
            year: latest_metric.year
          }
        end
      end
    end
    
    {
      countries: countries_data,
      metadata: {
        source: 'Our World in Data',
        last_updated: Metric.where(metric_name: metric_name).maximum(:updated_at)
      }
    }
  end
  
  def self.calculate_european_average(metric_name)
    # Major EU countries for averaging
    eu_countries = ['germany', 'france', 'italy', 'spain', 'netherlands', 'poland', 'sweden', 'denmark', 'finland', 'austria', 'belgium']
    
    # Get latest data for each EU country
    eu_metrics = []
    eu_countries.each do |country|
      metric = Metric.latest_for_country_and_metric(country, metric_name)
      eu_metrics << metric if metric
    end
    
    return nil if eu_metrics.empty?
    
    # Calculate average and get most recent year
    average_value = eu_metrics.sum(&:metric_value) / eu_metrics.count
    latest_year = eu_metrics.map(&:year).max
    
    {
      name: 'Europe',
      value: average_value.round(2),
      year: latest_year
    }
  end
  
  def self.calculate_and_store_europe_aggregate(metric_name)
    Rails.logger.info "Calculating and storing Europe aggregate for #{metric_name} via EuropeanMetricsService..."
    EuropeanMetricsService.calculate_europe_aggregate(metric_name)
    Rails.logger.info "Finished calculating Europe aggregate for #{metric_name}"
  end
end