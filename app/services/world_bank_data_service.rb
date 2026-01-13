require "net/http"
require "json"

# Service for fetching economic data from the World Bank API
# Documentation: https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation
class WorldBankDataService
  BASE_URL = "https://api.worldbank.org/v2"

  # World Bank indicator codes
  # Full list: https://data.worldbank.org/indicator
  INDICATORS = {
    # GDP nominal (current US$)
    gdp_nominal: {
      code: "NY.GDP.PCAP.CD",
      name: "GDP per capita (current US$)",
      unit: "current US$"
    },
    # GDP PPP for comparison
    gdp_ppp: {
      code: "NY.GDP.PCAP.PP.KD",
      name: "GDP per capita, PPP (constant 2021 international $)",
      unit: "PPP international $"
    },
    # GNI nominal
    gni_nominal: {
      code: "NY.GNP.PCAP.CD",
      name: "GNI per capita (current US$)",
      unit: "current US$"
    },
    # GNI PPP
    gni_ppp: {
      code: "NY.GNP.PCAP.PP.CD",
      name: "GNI per capita, PPP (current international $)",
      unit: "PPP international $"
    },
    # Population
    population: {
      code: "SP.POP.TOTL",
      name: "Population, total",
      unit: "people"
    }
  }.freeze

  # ISO 3166-1 alpha-2 country codes used by World Bank
  COUNTRY_CODES = {
    # EU-27 Member States (Core EU marked)
    "germany" => "DE",       # Core EU
    "france" => "FR",        # Core EU
    "italy" => "IT",         # Core EU
    "netherlands" => "NL",   # Core EU
    "belgium" => "BE",       # Core EU
    "luxembourg" => "LU",    # Core EU
    "spain" => "ES",
    "poland" => "PL",
    "sweden" => "SE",
    "denmark" => "DK",
    "finland" => "FI",
    "austria" => "AT",
    "czechia" => "CZ",
    "estonia" => "EE",
    "greece" => "GR",
    "hungary" => "HU",
    "ireland" => "IE",
    "latvia" => "LV",
    "lithuania" => "LT",
    "malta" => "MT",
    "portugal" => "PT",
    "slovakia" => "SK",
    "slovenia" => "SI",
    "bulgaria" => "BG",
    "croatia" => "HR",
    "romania" => "RO",
    "cyprus" => "CY",
    # Non-EU Western European Countries
    "norway" => "NO",
    "switzerland" => "CH",
    "united_kingdom" => "GB",
    "iceland" => "IS",
    # Eastern European Countries
    "ukraine" => "UA",
    "belarus" => "BY",
    "moldova" => "MD",
    # Balkan Countries
    "albania" => "AL",
    "bosnia_herzegovina" => "BA",
    "serbia" => "RS",
    "montenegro" => "ME",
    "north_macedonia" => "MK",
    "kosovo" => "XK",
    # Caucasus Countries
    "armenia" => "AM",
    "azerbaijan" => "AZ",
    "georgia" => "GE",
    # Transcontinental Countries
    "russia" => "RU",
    "turkey" => "TR",
    # Small States
    "andorra" => "AD",
    "monaco" => "MC",
    "san_marino" => "SM",
    "liechtenstein" => "LI",
    # Comparison countries
    "usa" => "US",
    "india" => "IN",
    "china" => "CN"
  }.freeze

  # Reverse mapping for lookups
  CODE_TO_COUNTRY = COUNTRY_CODES.invert.transform_keys(&:upcase).freeze

  class << self
    # Fetch GDP per capita in nominal terms (current US$)
    # @param countries [Array<String>] Country keys (e.g., ["germany", "france"])
    # @param start_year [Integer] Start year for data range
    # @param end_year [Integer] End year for data range
    # @return [Hash] Processed data by country and year
    def fetch_gdp_nominal(countries: nil, start_year: 2000, end_year: 2024)
      fetch_indicator(:gdp_nominal, countries: countries, start_year: start_year, end_year: end_year)
    end

    # Fetch GDP per capita PPP
    def fetch_gdp_ppp(countries: nil, start_year: 2000, end_year: 2024)
      fetch_indicator(:gdp_ppp, countries: countries, start_year: start_year, end_year: end_year)
    end

    # Fetch population
    def fetch_population(countries: nil, start_year: 2000, end_year: 2024)
      fetch_indicator(:population, countries: countries, start_year: start_year, end_year: end_year)
    end

    # Generic method to fetch any indicator
    # @param indicator [Symbol] Key from INDICATORS hash
    # @param countries [Array<String>] Country keys to fetch (nil = all available)
    # @param start_year [Integer] Start year
    # @param end_year [Integer] End year
    # @return [Hash] Processed data with :data, :metadata, and :countries keys
    def fetch_indicator(indicator, countries: nil, start_year: 2000, end_year: 2024)
      config = INDICATORS[indicator]
      raise ArgumentError, "Unknown indicator: #{indicator}" unless config

      indicator_code = config[:code]

      # Build country filter - World Bank uses semicolon-separated ISO2 codes
      country_codes = if countries
        countries.map { |c| COUNTRY_CODES[c] }.compact.join(";")
      else
        # Fetch all our tracked countries
        COUNTRY_CODES.values.join(";")
      end

      return { error: "No valid country codes found" } if country_codes.empty?

      url = build_url(country_codes, indicator_code, start_year, end_year)
      Rails.logger.info "World Bank API Request: #{url}"

      response = fetch_json(url)
      return { error: "Failed to fetch data from World Bank" } if response.nil?

      parse_response(response, indicator)
    rescue StandardError => e
      Rails.logger.error "World Bank API Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { error: e.message }
    end

    # List available indicators
    def available_indicators
      INDICATORS.keys
    end

    private

    def build_url(country_codes, indicator_code, start_year, end_year)
      # World Bank API format: /country/{codes}/indicator/{indicator}
      # Parameters: date (range), format (json), per_page (max results)
      date_range = "#{start_year}:#{end_year}"
      "#{BASE_URL}/country/#{country_codes}/indicator/#{indicator_code}?date=#{date_range}&format=json&per_page=10000"
    end

    def fetch_json(url)
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 60

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "EuropeVersus/1.0"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "World Bank HTTP Error: #{response.code} - #{response.message}"
        return nil
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      Rails.logger.error "World Bank JSON Parse Error: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "World Bank HTTP Error: #{e.message}"
      nil
    end

    def parse_response(response, indicator)
      # World Bank API returns [metadata, data] array
      return { error: "Invalid response format" } unless response.is_a?(Array) && response.length >= 2

      metadata = response[0]
      data_array = response[1]

      return { error: "No data returned" } if data_array.nil? || data_array.empty?

      config = INDICATORS[indicator]
      processed_data = {}
      countries_found = Set.new

      data_array.each do |entry|
        next if entry["value"].nil?

        country_code = entry.dig("country", "id")&.upcase
        country_key = CODE_TO_COUNTRY[country_code]

        next unless country_key

        year = entry["date"].to_i
        value = entry["value"].to_f

        processed_data[country_key] ||= {}
        processed_data[country_key][year] = value
        countries_found << country_key
      end

      {
        data: processed_data,
        metadata: {
          indicator: indicator,
          indicator_code: config[:code],
          indicator_name: config[:name],
          unit: config[:unit],
          source: "World Bank",
          source_url: "https://data.worldbank.org/indicator/#{config[:code]}",
          total_records: metadata["total"],
          fetched_at: Time.current.iso8601
        },
        countries: countries_found.to_a.sort
      }
    end
  end
end
