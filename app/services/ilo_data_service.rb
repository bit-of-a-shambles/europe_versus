require "net/http"
require "json"

# Service for fetching labor statistics from the International Labour Organization (ILO)
# Uses the ILOSTAT SDMX API
# Documentation: https://ilostat.ilo.org/resources/sdmx-tools/
class IloDataService
  BASE_URL = "https://sdmx.ilo.org/rest/data"

  # Available dataflows for labor productivity
  # Format: { dataflow_id, measure_code }
  # Dataflow IDs found by querying: https://sdmx.ilo.org/rest/dataflow/ILO
  DATAFLOWS = {
    # Output per hour worked (GDP constant 2021 international $ at PPP)
    labor_productivity_per_hour: {
      dataflow: "ILO,DF_GDP_2HRW_NOC_NB",
      measure: "GDP_2HRW_NB"
    },
    # Output per worker (GDP constant 2015 US $)
    labor_productivity_per_worker: {
      dataflow: "ILO,DF_GDP_205U_NOC_NB",
      measure: "GDP_205U_NB"
    }
  }.freeze

  # ISO 3166-1 alpha-3 country codes used by ILO
  # Maps our internal country keys to ILO country codes
  COUNTRY_CODES = {
    # EU-27 Member States
    "germany" => "DEU",
    "france" => "FRA",
    "italy" => "ITA",
    "spain" => "ESP",
    "netherlands" => "NLD",
    "poland" => "POL",
    "sweden" => "SWE",
    "denmark" => "DNK",
    "finland" => "FIN",
    "austria" => "AUT",
    "belgium" => "BEL",
    "czechia" => "CZE",
    "estonia" => "EST",
    "greece" => "GRC",
    "hungary" => "HUN",
    "ireland" => "IRL",
    "latvia" => "LVA",
    "lithuania" => "LTU",
    "luxembourg" => "LUX",
    "malta" => "MLT",
    "portugal" => "PRT",
    "slovakia" => "SVK",
    "slovenia" => "SVN",
    "bulgaria" => "BGR",
    "croatia" => "HRV",
    "romania" => "ROU",
    "cyprus" => "CYP",
    # Non-EU Western European Countries
    "norway" => "NOR",
    "switzerland" => "CHE",
    "united_kingdom" => "GBR",
    "iceland" => "ISL",
    # Eastern European Countries
    "ukraine" => "UKR",
    "belarus" => "BLR",
    "moldova" => "MDA",
    # Balkan Countries
    "albania" => "ALB",
    "bosnia_herzegovina" => "BIH",
    "serbia" => "SRB",
    "montenegro" => "MNE",
    "north_macedonia" => "MKD",
    "kosovo" => "XKX",
    # Caucasus Countries
    "armenia" => "ARM",
    "azerbaijan" => "AZE",
    "georgia" => "GEO",
    # Transcontinental Countries
    "russia" => "RUS",
    "turkey" => "TUR",
    # Small States
    "andorra" => "AND",
    "monaco" => "MCO",
    "san_marino" => "SMR",
    "liechtenstein" => "LIE",
    # vatican not available in ILO data
    # Comparison countries
    "usa" => "USA",
    "india" => "IND",
    "china" => "CHN"
  }.freeze

  # Reverse mapping for lookups
  CODE_TO_COUNTRY = COUNTRY_CODES.invert.freeze

  class << self
    # Fetch labor productivity per hour for specified countries
    # @param countries [Array<String>] Country keys (e.g., ["germany", "france"])
    # @param start_year [Integer] Start year for data range
    # @param end_year [Integer] End year for data range
    # @return [Hash] Processed data by country and year
    def fetch_labor_productivity_per_hour(countries: nil, start_year: 2000, end_year: 2024)
      fetch_indicator(:labor_productivity_per_hour, countries: countries, start_year: start_year, end_year: end_year)
    end

    # Fetch labor productivity per worker for specified countries
    def fetch_labor_productivity_per_worker(countries: nil, start_year: 2000, end_year: 2024)
      fetch_indicator(:labor_productivity_per_worker, countries: countries, start_year: start_year, end_year: end_year)
    end

    # Generic method to fetch any indicator
    # @param indicator [Symbol] Key from DATAFLOWS hash
    # @param countries [Array<String>] Country keys to fetch (nil = all available)
    # @param start_year [Integer] Start year
    # @param end_year [Integer] End year
    # @return [Hash] Processed data with :data, :metadata, and :countries keys
    def fetch_indicator(indicator, countries: nil, start_year: 2000, end_year: 2024)
      config = DATAFLOWS[indicator]
      raise ArgumentError, "Unknown indicator: #{indicator}" unless config

      dataflow = config[:dataflow]
      measure = config[:measure]

      # Build country filter - for multiple countries, join with +
      country_codes = if countries
        countries.map { |c| COUNTRY_CODES[c] }.compact.join("+")
      else
        "" # Empty means all countries
      end

      # ILO SDMX query format: REF_AREA.FREQ.MEASURE
      # e.g., DEU+FRA+USA.A.GDP_2HRW_NB
      key_filter = "#{country_codes}.A.#{measure}"

      url = build_url(dataflow, key_filter, start_year, end_year)
      Rails.logger.info "ILO API Request: #{url}"

      response = fetch_json(url)
      return { error: "Failed to fetch data from ILO" } if response.nil?

      parse_response(response, indicator)
    rescue StandardError => e
      Rails.logger.error "ILO API Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { error: e.message }
    end

    private

    def build_url(dataflow, key_filter, start_year, end_year)
      "#{BASE_URL}/#{dataflow}/#{key_filter}?startPeriod=#{start_year}&endPeriod=#{end_year}"
    end

    def fetch_json(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 60

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.sdmx.data+json;version=1.0"
      request["User-Agent"] = "EuropeVersus/1.0 (Rails Application)"

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        Rails.logger.error "ILO API HTTP #{response.code}: #{response.body[0..500]}"
        nil
      end
    end

    def parse_response(json_response, indicator)
      data_structure = json_response.dig("data", "structure")
      data_sets = json_response.dig("data", "dataSets")

      return { error: "No data structure in response" } unless data_structure
      return { error: "No datasets in response" } if data_sets.nil? || data_sets.empty?

      # Extract dimension information
      series_dims = data_structure.dig("dimensions", "series") || []
      obs_dims = data_structure.dig("dimensions", "observation") || []

      # Build lookups for dimension values
      ref_area_dim = series_dims.find { |d| d["id"] == "REF_AREA" }
      time_dim = obs_dims.find { |d| d["id"] == "TIME_PERIOD" }

      return { error: "Missing dimension information" } unless ref_area_dim && time_dim

      country_lookup = build_lookup(ref_area_dim["values"])
      year_lookup = build_lookup(time_dim["values"])

      # Parse the series data
      result = {
        data: {},
        metadata: {
          indicator: indicator,
          unit: get_unit_for_indicator(indicator),
          source: "ILO - Modelled Estimates",
          last_updated: json_response.dig("meta", "prepared")
        },
        countries: []
      }

      series = data_sets.first["series"] || {}

      series.each do |series_key, series_data|
        # series_key format: "0:0:0" (country_idx:freq_idx:measure_idx)
        indices = series_key.split(":").map(&:to_i)
        country_idx = indices[0]

        country_code = country_lookup[country_idx]
        country_key = CODE_TO_COUNTRY[country_code]

        # Skip countries we don't track
        next unless country_key

        result[:data][country_key] ||= {}
        result[:countries] << country_key unless result[:countries].include?(country_key)

        observations = series_data["observations"] || {}
        observations.each do |time_idx, obs_array|
          year = year_lookup[time_idx.to_i]
          value = obs_array[0] # First element is the observation value

          next unless year && value

          result[:data][country_key][year.to_i] = value.to_f
        end
      end

      result[:countries].sort!
      result
    end

    def build_lookup(values)
      lookup = {}
      values.each_with_index do |v, idx|
        lookup[idx] = v["id"]
      end
      lookup
    end

    def get_unit_for_indicator(indicator)
      case indicator
      when :labor_productivity_per_hour
        "2021 PPP $ per hour"
      when :labor_productivity_per_worker
        "2015 USD per worker"
      else
        "units"
      end
    end
  end
end
