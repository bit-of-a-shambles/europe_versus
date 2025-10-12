module EuropeanCountriesHelper
  # Comprehensive list of all European countries and territories
  # Includes population adjustments for transcontinental countries
  EUROPEAN_COUNTRIES = {
    # EU Member States (27)
    'germany' => { population_factor: 1.0, region: 'Western Europe' },
    'france' => { population_factor: 1.0, region: 'Western Europe' },
    'italy' => { population_factor: 1.0, region: 'Southern Europe' },
    'spain' => { population_factor: 1.0, region: 'Southern Europe' },
    'netherlands' => { population_factor: 1.0, region: 'Western Europe' },
    'poland' => { population_factor: 1.0, region: 'Central Europe' },
    'sweden' => { population_factor: 1.0, region: 'Northern Europe' },
    'denmark' => { population_factor: 1.0, region: 'Northern Europe' },
    'finland' => { population_factor: 1.0, region: 'Northern Europe' },
    'austria' => { population_factor: 1.0, region: 'Central Europe' },
    'belgium' => { population_factor: 1.0, region: 'Western Europe' },
    'ireland' => { population_factor: 1.0, region: 'Northern Europe' },
    'portugal' => { population_factor: 1.0, region: 'Southern Europe' },
    'greece' => { population_factor: 1.0, region: 'Southern Europe' },
    'czechia' => { population_factor: 1.0, region: 'Central Europe' },
    'hungary' => { population_factor: 1.0, region: 'Central Europe' },
    'romania' => { population_factor: 1.0, region: 'Eastern Europe' },
    'croatia' => { population_factor: 1.0, region: 'Southern Europe' },
    'bulgaria' => { population_factor: 1.0, region: 'Eastern Europe' },
    'slovakia' => { population_factor: 1.0, region: 'Central Europe' },
    'slovenia' => { population_factor: 1.0, region: 'Central Europe' },
    'estonia' => { population_factor: 1.0, region: 'Northern Europe' },
    'latvia' => { population_factor: 1.0, region: 'Northern Europe' },
    'lithuania' => { population_factor: 1.0, region: 'Northern Europe' },
    'luxembourg' => { population_factor: 1.0, region: 'Western Europe' },
    'malta' => { population_factor: 1.0, region: 'Southern Europe' },
    'cyprus' => { population_factor: 1.0, region: 'Southern Europe' },
    
    # Non-EU Western European Countries
    'switzerland' => { population_factor: 1.0, region: 'Western Europe' },
    'norway' => { population_factor: 1.0, region: 'Northern Europe' },
    'united_kingdom' => { population_factor: 1.0, region: 'Northern Europe' },
    'iceland' => { population_factor: 1.0, region: 'Northern Europe' },
    
    # Eastern European Countries
    'ukraine' => { population_factor: 1.0, region: 'Eastern Europe' },
    'belarus' => { population_factor: 1.0, region: 'Eastern Europe' },
    'moldova' => { population_factor: 1.0, region: 'Eastern Europe' },
    
    # Balkan Countries
    'albania' => { population_factor: 1.0, region: 'Southern Europe' },
    'bosnia_herzegovina' => { population_factor: 1.0, region: 'Southern Europe' },
    'serbia' => { population_factor: 1.0, region: 'Southern Europe' },
    'montenegro' => { population_factor: 1.0, region: 'Southern Europe' },
    'north_macedonia' => { population_factor: 1.0, region: 'Southern Europe' },
    'kosovo' => { population_factor: 1.0, region: 'Southern Europe' },
    
    # Caucasus (European portion)
    'armenia' => { population_factor: 1.0, region: 'Eastern Europe' },
    'azerbaijan' => { population_factor: 0.3, region: 'Eastern Europe' }, # ~30% in Europe (north of Greater Caucasus)
    'georgia' => { population_factor: 1.0, region: 'Eastern Europe' },
    
    # Transcontinental Countries (European portion only)
    'russia' => { population_factor: 0.77, region: 'Eastern Europe' }, # ~77% of population lives in European Russia
    'turkey' => { population_factor: 0.14, region: 'Southern Europe' }, # ~14% of population lives in European Turkey (Thrace)
    
    # Small States and Dependencies
    'andorra' => { population_factor: 1.0, region: 'Southern Europe' },
    'monaco' => { population_factor: 1.0, region: 'Western Europe' },
    'san_marino' => { population_factor: 1.0, region: 'Southern Europe' },
    'vatican' => { population_factor: 1.0, region: 'Southern Europe' },
    'liechtenstein' => { population_factor: 1.0, region: 'Western Europe' }
  }.freeze
  
  # Get all European country keys
  def self.all_european_countries
    EUROPEAN_COUNTRIES.keys
  end
  
  # Get human-readable country name
  def self.country_name(country_key)
    return nil if country_key.nil?
    
    # Special cases for better formatting
    case country_key.to_s
    when 'czechia'
      'Czechia'
    when 'united_kingdom'
      'United Kingdom'
    when 'bosnia_herzegovina'
      'Bosnia & Herzegovina'
    when 'north_macedonia'
      'North Macedonia'
    when 'san_marino'
      'San Marino'
    else
      country_key.to_s.humanize.titleize
    end
  end
  
  # Get European countries by region
  def self.countries_by_region(region)
    EUROPEAN_COUNTRIES.select { |_, info| info[:region] == region }.keys
  end
  
  # Get population factor for a country (handles transcontinental adjustments)
  def self.population_factor(country_key)
    return 1.0 if country_key.nil?
    
    normalized_key = country_key.to_s.downcase
    country_info = EUROPEAN_COUNTRIES[normalized_key]
    return 1.0 unless country_info
    
    country_info[:population_factor] || 1.0
  end
  
  # Calculate European portion of population for a country
  def self.european_population(country_key, total_population)
    return 0 if country_key.nil? || total_population.nil? || total_population < 0
    
    factor = population_factor(country_key)
    (total_population * factor)
  end
  
  # Get countries that have GDP data available
  def self.countries_with_gdp_data(available_countries = [])
    return [] if available_countries.nil?
    
    available_countries.select { |country| all_european_countries.include?(country) }
  end
  
  # Get comprehensive list with metadata
  def self.country_info(country_key)
    EUROPEAN_COUNTRIES[country_key]
  end
end