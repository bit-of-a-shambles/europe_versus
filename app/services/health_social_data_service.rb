require 'net/http'
require 'json'

class HealthSocialDataService
  # Health and social metrics from Our World in Data
  HEALTH_SOCIAL_METRICS = {
    'healthcare_spending_per_capita' => 'healthcare-expenditure-per-capita',
    'education_spending_gdp' => 'government-expenditure-on-education-of-gdp',
    'unemployment_rate' => 'unemployment-rate',
    'happiness_index' => 'happiness-cantril-ladder',
    'internet_users' => 'share-of-individuals-using-the-internet'
  }.freeze

  def self.latest_healthcare_spending_for_countries(countries = ['europe', 'usa', 'india', 'china'])
    Rails.logger.info "HealthSocialDataService#latest_healthcare_spending_for_countries called with: #{countries.inspect}"
    
    result = {}
    
    # Fetch healthcare spending per capita data
    healthcare_data = OurWorldInDataService.fetch_chart_data('healthcare-expenditure-per-capita', start_year: 2015, end_year: 2024)
    
    unless healthcare_data[:error]
      countries.each do |country_key|
        country_data = healthcare_data[:countries][country_key]
        if country_data && !country_data[:data].empty?
          # Get the latest year with data
          latest_year = country_data[:data].keys.max
          latest_value = country_data[:data][latest_year]
          
          result[country_key] = {
            value: latest_value,
            year: latest_year,
            unit: healthcare_data[:metadata][:unit] || 'USD per person'
          }
        else
          Rails.logger.warn "No healthcare spending data found for #{country_key}"
          result[country_key] = { value: nil, year: nil, unit: 'USD per person' }
        end
      end
    end
    
    Rails.logger.info "HealthSocialDataService healthcare result: #{result.inspect}"
    result
  end

  def self.latest_education_spending_for_countries(countries = ['europe', 'usa', 'india', 'china'])
    Rails.logger.info "HealthSocialDataService#latest_education_spending_for_countries called with: #{countries.inspect}"
    
    result = {}
    
    # Fetch education spending as % of GDP data
    education_data = OurWorldInDataService.fetch_chart_data('government-expenditure-on-education-of-gdp', start_year: 2015, end_year: 2024)
    
    unless education_data[:error]
      countries.each do |country_key|
        country_data = education_data[:countries][country_key]
        if country_data && !country_data[:data].empty?
          # Get the latest year with data
          latest_year = country_data[:data].keys.max
          latest_value = country_data[:data][latest_year]
          
          result[country_key] = {
            value: latest_value,
            year: latest_year,
            unit: education_data[:metadata][:unit] || '% of GDP'
          }
        else
          Rails.logger.warn "No education spending data found for #{country_key}"
          result[country_key] = { value: nil, year: nil, unit: '% of GDP' }
        end
      end
    end
    
    Rails.logger.info "HealthSocialDataService education result: #{result.inspect}"
    result
  end

  def self.latest_happiness_for_countries(countries = ['europe', 'usa', 'india', 'china'])
    Rails.logger.info "HealthSocialDataService#latest_happiness_for_countries called with: #{countries.inspect}"
    
    result = {}
    
    # Fetch happiness index data (Cantril Ladder)
    happiness_data = OurWorldInDataService.fetch_chart_data('happiness-cantril-ladder', start_year: 2015, end_year: 2024)
    
    unless happiness_data[:error]
      countries.each do |country_key|
        country_data = happiness_data[:countries][country_key]
        if country_data && !country_data[:data].empty?
          # Get the latest year with data
          latest_year = country_data[:data].keys.max
          latest_value = country_data[:data][latest_year]
          
          result[country_key] = {
            value: latest_value,
            year: latest_year,
            unit: happiness_data[:metadata][:unit] || 'Score (0-10)'
          }
        else
          Rails.logger.warn "No happiness data found for #{country_key}"
          result[country_key] = { value: nil, year: nil, unit: 'Score (0-10)' }
        end
      end
    end
    
    Rails.logger.info "HealthSocialDataService happiness result: #{result.inspect}"
    result
  end

  def self.latest_internet_usage_for_countries(countries = ['europe', 'usa', 'india', 'china'])
    Rails.logger.info "HealthSocialDataService#latest_internet_usage_for_countries called with: #{countries.inspect}"
    
    result = {}
    
    # Fetch internet users data
    internet_data = OurWorldInDataService.fetch_chart_data('share-of-individuals-using-the-internet', start_year: 2015, end_year: 2024)
    
    unless internet_data[:error]
      countries.each do |country_key|
        country_data = internet_data[:countries][country_key]
        if country_data && !country_data[:data].empty?
          # Get the latest year with data
          latest_year = country_data[:data].keys.max
          latest_value = country_data[:data][latest_year]
          
          result[country_key] = {
            value: latest_value,
            year: latest_year,
            unit: internet_data[:metadata][:unit] || '% of population'
          }
        else
          Rails.logger.warn "No internet usage data found for #{country_key}"
          result[country_key] = { value: nil, year: nil, unit: '% of population' }
        end
      end
    end
    
    Rails.logger.info "HealthSocialDataService internet result: #{result.inspect}"
    result
  end

  # Fetch and store health expenditure as % of GDP (full historical data)
  def self.fetch_and_store_health_expenditure_gdp
    puts "Fetching health expenditure as % of GDP data..."
    
    result = OurWorldInDataService.fetch_chart_data(
      'total-healthcare-expenditure-gdp',
      start_year: 2000,
      end_year: 2024
    )
    
    return result if result[:error]
    
    store_metric_data(result, 'health_expenditure_gdp_percent')
    calculate_aggregates('health_expenditure_gdp_percent')
    
    puts "✅ Health expenditure data stored"
    result
  end

  # Fetch and store life satisfaction/happiness data (full historical data)
  def self.fetch_and_store_life_satisfaction
    puts "Fetching life satisfaction (happiness) data..."
    
    result = OurWorldInDataService.fetch_chart_data(
      'happiness-cantril-ladder',
      start_year: 2010,
      end_year: 2024
    )
    
    return result if result[:error]
    
    store_metric_data(result, 'life_satisfaction')
    calculate_aggregates('life_satisfaction')
    
    puts "✅ Life satisfaction data stored"
    result
  end

  private

  def self.store_metric_data(result, metric_name)
    stored_count = 0
    
    result[:countries].each do |country_key, country_data|
      country_data[:data].each do |year, value|
        # Skip if value is nil or empty
        next if value.nil? || value.to_s.strip.empty?
        
        # Convert to float and skip if invalid
        numeric_value = value.to_f
        next if numeric_value.nan? || numeric_value.infinite?
        
        # Use .presence to handle empty strings
        unit_value = result.dig(:metadata, :unit).presence || determine_unit(metric_name)
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
          source: result.dig(:metadata, :source) || 'Our World in Data',
          description: result.dig(:metadata, :description)
        )
        
        metric.save!
        stored_count += 1
      end
    end
    
    puts "   → Stored #{stored_count} records across #{result[:countries].size} countries"
  end

  def self.calculate_aggregates(metric_name)
    puts "   → Calculating Europe aggregate for #{metric_name}..."
    EuropeanMetricsService.calculate_europe_aggregate(metric_name)
    
    puts "   → Calculating EU-27 aggregate for #{metric_name}..."
    EuropeanMetricsService.calculate_group_aggregate(
      metric_name,
      country_keys: EuropeanMetricsService::EU27_COUNTRIES,
      target_key: 'european_union'
    )
  end

  def self.determine_unit(metric_name)
    case metric_name
    when 'health_expenditure_gdp_percent'
      '% of GDP'
    when 'life_satisfaction'
      'score (0-10)'
    else
      'unknown'
    end
  end
end