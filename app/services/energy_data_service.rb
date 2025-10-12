require 'net/http'
require 'json'

class EnergyDataService
  extend OurWorldInDataService
  
  # Energy consumption metrics from Our World in Data
  ENERGY_METRICS = {
    'energy_consumption_per_capita' => 'per-capita-energy-use',
    'renewable_energy_share' => 'renewable-share-energy',
    'electricity_consumption_per_capita' => 'per-capita-electricity-use',
    'co2_emissions_per_capita' => 'co2-per-capita'
  }.freeze

  def self.latest_energy_for_countries(countries = ['europe', 'usa', 'india', 'china'])
    Rails.logger.info "EnergyDataService#latest_energy_for_countries called with: #{countries.inspect}"
    
    result = {}
    
    # Fetch energy consumption per capita data
    energy_data = fetch_chart_data('per-capita-energy-use', start_year: 2015, end_year: 2024)
    
    unless energy_data[:error]
      countries.each do |country_key|
        country_data = energy_data[:countries][country_key]
        if country_data && !country_data[:data].empty?
          # Get the latest year with data
          latest_year = country_data[:data].keys.max
          latest_value = country_data[:data][latest_year]
          
          result[country_key] = {
            value: latest_value,
            year: latest_year,
            unit: energy_data[:metadata][:unit] || 'kWh per person'
          }
        else
          Rails.logger.warn "No energy data found for #{country_key}"
          result[country_key] = { value: nil, year: nil, unit: 'kWh per person' }
        end
      end
    end
    
    Rails.logger.info "EnergyDataService result: #{result.inspect}"
    result
  end

  def self.latest_renewable_energy_for_countries(countries = ['europe', 'usa', 'india', 'china'])
    Rails.logger.info "EnergyDataService#latest_renewable_energy_for_countries called with: #{countries.inspect}"
    
    result = {}
    
    # Fetch renewable energy share data
    renewable_data = fetch_chart_data('renewable-share-energy', start_year: 2015, end_year: 2024)
    
    unless renewable_data[:error]
      countries.each do |country_key|
        country_data = renewable_data[:countries][country_key]
        if country_data && !country_data[:data].empty?
          # Get the latest year with data
          latest_year = country_data[:data].keys.max
          latest_value = country_data[:data][latest_year]
          
          result[country_key] = {
            value: latest_value,
            year: latest_year,
            unit: renewable_data[:metadata][:unit] || '%'
          }
        else
          Rails.logger.warn "No renewable energy data found for #{country_key}"
          result[country_key] = { value: nil, year: nil, unit: '%' }
        end
      end
    end
    
    Rails.logger.info "EnergyDataService renewable result: #{result.inspect}"
    result
  end

  def self.latest_co2_emissions_for_countries(countries = ['europe', 'usa', 'india', 'china'])
    Rails.logger.info "EnergyDataService#latest_co2_emissions_for_countries called with: #{countries.inspect}"
    
    result = {}
    
    # Fetch CO2 emissions per capita data
    co2_data = fetch_chart_data('co2-per-capita', start_year: 2015, end_year: 2024)
    
    unless co2_data[:error]
      countries.each do |country_key|
        country_data = co2_data[:countries][country_key]
        if country_data && !country_data[:data].empty?
          # Get the latest year with data
          latest_year = country_data[:data].keys.max
          latest_value = country_data[:data][latest_year]
          
          result[country_key] = {
            value: latest_value,
            year: latest_year,
            unit: co2_data[:metadata][:unit] || 'tonnes per person'
          }
        else
          Rails.logger.warn "No CO2 emissions data found for #{country_key}"
          result[country_key] = { value: nil, year: nil, unit: 'tonnes per person' }
        end
      end
    end
    
    Rails.logger.info "EnergyDataService CO2 result: #{result.inspect}"
    result
  end
end