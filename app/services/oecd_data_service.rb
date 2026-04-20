require "net/http"
require "csv"

# Service for fetching economic data from the OECD SDMX API
# Documentation: https://data-explorer.oecd.org/
#
# Primary datasets:
#   - PPP price level indices (household final consumption, OECD=100)
#   - Taxing wages (average PIT + employee SSC rates)
#
# Uses CSV format from OECD SDMX REST API for easier parsing than JSON.
class OecdDataService
  BASE_URL = "https://sdmx.oecd.org/public/rest/data"

  # OECD country codes (ISO3) → project country keys
  COUNTRY_CODES = {
    "AUT" => "austria",
    "BEL" => "belgium",
    "BGR" => "bulgaria",
    "CHE" => "switzerland",
    "CYP" => "cyprus",
    "CZE" => "czechia",
    "DEU" => "germany",
    "DNK" => "denmark",
    "ESP" => "spain",
    "EST" => "estonia",
    "FIN" => "finland",
    "FRA" => "france",
    "GBR" => "united_kingdom",
    "GRC" => "greece",
    "HRV" => "croatia",
    "HUN" => "hungary",
    "IRL" => "ireland",
    "ISL" => "iceland",
    "ITA" => "italy",
    "JPN" => "japan",
    "LTU" => "lithuania",
    "LUX" => "luxembourg",
    "LVA" => "latvia",
    "MLT" => "malta",
    "NLD" => "netherlands",
    "NOR" => "norway",
    "POL" => "poland",
    "PRT" => "portugal",
    "ROU" => "romania",
    "SVK" => "slovakia",
    "SVN" => "slovenia",
    "SWE" => "sweden",
    "TUR" => "turkey",
    "USA" => "usa",
    "IND" => "india",
    "CHN" => "china",
    "EU27_2020" => "eu27"
  }.freeze

  # Available OECD datasets
  DATASETS = {
    # PPP price level index for household final consumption expenditure (OECD=100)
    ppp_price_level: {
      # Dataflow: OECD.SDD.TPS,DSD_PPP@DF_PPP_CPL,1.1
      # Dimensions: REF_AREA.FREQ.MEASURE.INDICATOR.UNIT_MEASURE.SCALING
      path: "OECD.SDD.TPS,DSD_PPP@DF_PPP_CPL,1.1/.A.PL.E011.IX.OECD",
      unit: "Index (OECD=100)",
      description: "Comparative price level index for household final consumption expenditure, OECD=100"
    },
    # Average PIT + employee SSC rate (single, no children, 100% AW)
    avg_tax_rate: {
      # Dataflow: OECD.CTP.TPS,DSD_TAX_PIT@DF_PIT_AV,1.0
      path: "OECD.CTP.TPS,DSD_TAX_PIT@DF_PIT_AV,1.0/.A.AVG_R.PIT_EESSC.PT_WG_EARN_G.S13.S.S_C0.AW100._Z._Z._Z",
      unit: "% of gross wage earnings",
      description: "Average personal income tax + employee social security contribution rate, single no children at 100% average wage"
    }
  }.freeze

  class << self
    # Fetch PPP price level indices for all OECD/partner countries
    #
    # @param start_year [Integer] Start year
    # @param end_year [Integer] End year
    # @return [Hash] { data: { country => { year => value } }, metadata: {...} }
    def fetch_ppp_price_levels(start_year: 2000, end_year: 2024)
      fetch_indicator(:ppp_price_level, start_year: start_year, end_year: end_year)
    end

    # Fetch average tax rates
    def fetch_avg_tax_rates(start_year: 2000, end_year: 2024)
      fetch_indicator(:avg_tax_rate, start_year: start_year, end_year: end_year)
    end

    # Generic indicator fetch
    def fetch_indicator(indicator, start_year: 2000, end_year: 2024)
      config = DATASETS[indicator]
      raise ArgumentError, "Unknown indicator: #{indicator}" unless config

      url = "#{BASE_URL}/#{config[:path]}?startPeriod=#{start_year}&endPeriod=#{end_year}"
      Rails.logger.info "OECD API Request: #{url}"

      csv_text = fetch_csv(url)
      return { error: "Failed to fetch data from OECD" } if csv_text.nil?

      parse_csv_response(csv_text, config)
    rescue StandardError => e
      Rails.logger.error "OECD API Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { error: e.message }
    end

    private

    def fetch_csv(url)
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 120

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "text/csv"
      request["User-Agent"] = "EuropeVersus/1.0"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "OECD HTTP Error: #{response.code} - #{response.message}"
        return nil
      end

      response.body
    rescue StandardError => e
      Rails.logger.error "OECD HTTP Error: #{e.message}"
      nil
    end

    def parse_csv_response(csv_text, config)
      rows = CSV.parse(csv_text, headers: true)

      processed_data = {}
      countries_found = Set.new

      rows.each do |row|
        # OECD SDMX CSV uses REF_AREA for country code and TIME_PERIOD for year
        country_code = row["REF_AREA"]
        country_key = COUNTRY_CODES[country_code]
        next unless country_key

        year = row["TIME_PERIOD"].to_i
        next if year < 1900

        value = row["OBS_VALUE"]
        next if value.nil? || value.to_s.strip.empty?

        numeric = value.to_f

        processed_data[country_key] ||= {}
        processed_data[country_key][year] = numeric
        countries_found << country_key
      end

      {
        data: processed_data,
        metadata: {
          source: "OECD",
          source_url: "https://data-explorer.oecd.org/",
          unit: config[:unit],
          description: config[:description],
          fetched_at: Time.current.iso8601
        },
        countries: countries_found.to_a.sort
      }
    end
  end
end
