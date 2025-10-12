require 'net/http'
require 'json'
require 'csv'

class OurWorldInDataService
  BASE_URL = 'https://ourworldindata.org/grapher'
  
  # Country mappings for Our World in Data entity names
  COUNTRIES = {
    # All EU-27 Member States
    'germany' => 'Germany',
    'france' => 'France',
    'italy' => 'Italy',
    'spain' => 'Spain',
    'netherlands' => 'Netherlands',
    'poland' => 'Poland',
    'sweden' => 'Sweden',
    'denmark' => 'Denmark',
    'finland' => 'Finland',
    'austria' => 'Austria',
    'belgium' => 'Belgium',
    'czechia' => 'Czechia',
    'estonia' => 'Estonia',
    'greece' => 'Greece',
    'hungary' => 'Hungary',
    'ireland' => 'Ireland',
    'latvia' => 'Latvia',
    'lithuania' => 'Lithuania',
    'luxembourg' => 'Luxembourg',
    'malta' => 'Malta',
    'portugal' => 'Portugal',
    'slovakia' => 'Slovakia',
    'slovenia' => 'Slovenia',
    'bulgaria' => 'Bulgaria',
    'croatia' => 'Croatia',
    'romania' => 'Romania',
    'cyprus' => 'Cyprus',
    # Other European Countries
    'norway' => 'Norway',
    'switzerland' => 'Switzerland',
    'united_kingdom' => 'United Kingdom',
    'iceland' => 'Iceland',
    # EU/Europe aggregates (using exact OWID names)
    'europe_central_asia' => 'Europe and Central Asia (WB)',
    'european_union' => 'European Union',
    # Comparison countries
    'usa' => 'United States', 
    'india' => 'India',
    'china' => 'China'
  }.freeze
  
  def self.fetch_chart_data(chart_name, start_year: 2000, end_year: 2024)
    begin
      # Fetch CSV data
      csv_response = fetch_csv_data(chart_name)
      
      if csv_response.code == '200'
        Rails.logger.info "CSV Response body preview: #{csv_response.body[0..200]}"
        data = parse_csv_data(csv_response.body)
        Rails.logger.info "Parsed data sample: #{data.first(2)}"
        metadata = fetch_chart_metadata(chart_name)
        
        process_chart_data(data, metadata, start_year, end_year, chart_name)
      else
        Rails.logger.error "Failed to fetch CSV data: #{csv_response.code}"
        { error: "Failed to fetch data: HTTP #{csv_response.code}" }
      end
    rescue StandardError => e
      Rails.logger.error "Error fetching Our World in Data: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5)}"
      { error: e.message }
    end
  end
  
  # Backward compatibility method
  def self.fetch_gdp_per_capita_ppp(countries: COUNTRIES.values, start_year: 2000, end_year: 2024)
    fetch_chart_data('gdp-per-capita-worldbank', start_year: start_year, end_year: end_year)
  end
  
  private
  
  def self.fetch_csv_data(chart_name)
    uri = URI("#{BASE_URL}/#{chart_name}.csv")
    Net::HTTP.get_response(uri)
  end

  def self.fetch_chart_metadata(chart_name)
    uri = URI("#{BASE_URL}/#{chart_name}.metadata.json")
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.warn "Failed to fetch metadata for #{chart_name}: #{response.code}"
      {}
    end
  end

  def self.parse_csv_data(csv_string)
    begin
      csv_data = CSV.parse(csv_string, headers: true)
      Rails.logger.info "CSV headers: #{csv_data.headers}"
      csv_data.map(&:to_h)
    rescue => e
      Rails.logger.error "CSV parsing error: #{e.message}"
      Rails.logger.error "CSV content preview: #{csv_string[0..500]}"
      raise e
    end
  end

  def self.process_chart_data(data, metadata, start_year, end_year, chart_name)
    return { error: "No data received" } if data.empty?
    
    # Find the data column (should be the column that's not Entity, Code, or Year)
    first_row = data.first
    data_column = first_row.keys.find { |k| !['Entity', 'Code', 'Year'].include?(k) }
    
    return { error: "No data column found" } unless data_column
    
    result = {
      countries: {},
      years: [],
      chart_name: chart_name,
      metadata: {
        source: metadata.dig('columns', data_column, 'citationShort') || 'Our World in Data',
        description: metadata.dig('columns', data_column, 'descriptionShort') || metadata.dig('chart', 'subtitle') || 'Data from Our World in Data',
        unit: metadata.dig('columns', data_column, 'unit') || metadata.dig('columns', data_column, 'shortUnit') || '',
        title: metadata.dig('chart', 'title') || chart_name.humanize,
        column_name: data_column
      }
    }

    # Initialize country data structures
    COUNTRIES.each do |key, country_name|
      result[:countries][key] = { name: country_name, data: {} }
    end

    # Process the data
    data.each do |row|
      entity = row['Entity']
      year = row['Year']&.to_i
      value = row[data_column]
      
      # Skip if outside year range or no value
      next if !year || year < start_year || year > end_year || value.nil? || value.empty?
      
      # Find matching country
      country_key = COUNTRIES.find { |k, v| v == entity }&.first
      
      if country_key
        result[:countries][country_key][:data][year] = value.to_f
        result[:years] << year unless result[:years].include?(year)
      end
    end

    result[:years].sort!
    result
  end
end