class Metric < ApplicationRecord
  validates :country, presence: true
  validates :metric_name, presence: true
  validates :metric_value, presence: true, numericality: { greater_than: 0 }
  validates :year, presence: true, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 1900, 
    less_than_or_equal_to: Date.current.year + 10 
  }
  validates :unit, presence: true
  
  # Ensure unique combination of country, metric, and year
  validates :country, uniqueness: { scope: [:metric_name, :year] }
  
  scope :for_metric, ->(metric_name) { where(metric_name: metric_name) }
  scope :for_country, ->(country) { where(country: country) }
  scope :for_year, ->(year) { where(year: year) }
  scope :latest_by_metric, ->(metric_name) { for_metric(metric_name).order(year: :desc) }
  
  # Get latest data for a specific metric across all countries
  def self.latest_for_metric(metric_name)
    subquery = where(metric_name: metric_name)
               .select('country, MAX(year) as max_year')
               .group(:country)
    
    joins("INNER JOIN (#{subquery.to_sql}) latest ON metrics.country = latest.country AND metrics.year = latest.max_year")
      .where(metric_name: metric_name)
  end
  
  # Get latest metric for specific country and metric type
  def self.latest_for_country_and_metric(country, metric_name)
    where(country: country, metric_name: metric_name).order(:year).last
  end
  
  # Display methods
  def display_name
    case country.downcase
    when 'europe'
      'Europe'
    when 'usa'
      'United States'
    when 'china'
      'China'
    when 'india'
      'India'
    when 'germany'
      'Germany'
    when 'france'
      'France'
    when 'united_kingdom'
      'United Kingdom'
    when 'russia'
      'Russia'
    when 'turkey'
      'Turkey'
    else
      country.titleize
    end
  end
  
  def metric_display_name
    case metric_name.downcase
    when 'population'
      'Population'
    when 'gdp_per_capita_ppp'
      'GDP per Capita (PPP)'
    when 'life_expectancy'
      'Life Expectancy'
    when 'birth_rate'
      'Birth Rate'
    when 'death_rate'
      'Death Rate'
    when 'literacy_rate'
      'Literacy Rate'
    when 'energy_consumption_per_capita'
      'Energy Consumption per Capita'
    when 'renewable_energy_share'
      'Renewable Energy Share'
    when 'healthcare_spending_per_capita'
      'Healthcare Spending per Capita'
    when 'happiness_index'
      'Happiness Index'
    when 'internet_users'
      'Internet Users'
    when 'co2_emissions_per_capita'
      'CO2 Emissions per Capita'
    when 'child_mortality_rate'
      'Child Mortality Rate'
    when 'electricity_access'
      'Access to Electricity'
    else
      metric_name.humanize
    end
  end
  
  def formatted_value
    case metric_name.downcase
    when 'population'
      # Format population in millions
      millions = metric_value / 1_000_000.0
      "#{millions.round(1)}M"
    when 'gdp_per_capita_ppp'
      # Format GDP with currency and thousands separator
      "$#{metric_value.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    when 'life_expectancy'
      # Format life expectancy with one decimal
      metric_value.round(1).to_s
    when 'energy_consumption_per_capita'
      # Format energy consumption with units
      "#{metric_value.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} kWh"
    when 'renewable_energy_share'
      # Format percentage
      "#{metric_value.round(1)}%"
    when 'healthcare_spending_per_capita'
      # Format healthcare spending with currency
      "$#{metric_value.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    when 'happiness_index'
      # Format happiness score
      metric_value.round(1).to_s
    when 'internet_users'
      # Format percentage
      "#{metric_value.round(1)}%"
    when 'co2_emissions_per_capita'
      # Format CO2 emissions
      "#{metric_value.round(1)} tonnes"
    when 'child_mortality_rate'
      # Format percentage
      "#{metric_value.round(1)}%"
    when 'literacy_rate'
      # Format percentage
      "#{metric_value.round(1)}%"
    when 'electricity_access'
      # Format percentage
      "#{metric_value.round(1)}%"
    else
      # Default formatting
      metric_value.round(1).to_s
    end
  end
end