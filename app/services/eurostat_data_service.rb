require "net/http"
require "json"

# Service for fetching economic data from the Eurostat API (JSON-stat format)
# Documentation: https://wikis.ec.europa.eu/display/EUROSTATHELP/API+Statistics
#
# Primary dataset: earn_nt_net (Annual net earnings)
#   - Single person, no children, 100% of average wage
#   - Available in EUR and PPS (purchasing power standard)
#   - Covers EU-27 + EFTA + UK + Turkey + US + Japan
#   - Years: 2000–2024
class EurostatDataService
  BASE_URL = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"

  # Bulgaria's "EUR" column in earn_nt_net is actually reported in BGN (Bulgarian Lev).
  # The BGN is pegged to EUR at this fixed rate since 1999.
  BGN_PER_EUR = 1.95583

  # GBP/EUR exchange rate for 2024 UK proxy calculation
  GBP_PER_EUR_2024 = 0.87105

  # ONS median gross annual earnings 2024 (full-time employees, UK)
  UK_ONS_GROSS_GBP_2024 = 37_439.0

  # Eurostat geo codes → project country keys
  GEO_TO_COUNTRY = {
    "AT" => "austria",
    "BE" => "belgium",
    "BG" => "bulgaria",
    "CH" => "switzerland",
    "CY" => "cyprus",
    "CZ" => "czechia",
    "DE" => "germany",
    "DK" => "denmark",
    "EE" => "estonia",
    "EL" => "greece",
    "ES" => "spain",
    "FI" => "finland",
    "FR" => "france",
    "HR" => "croatia",
    "HU" => "hungary",
    "IE" => "ireland",
    "IS" => "iceland",
    "IT" => "italy",
    "JP" => "japan",
    "LT" => "lithuania",
    "LU" => "luxembourg",
    "LV" => "latvia",
    "MT" => "malta",
    "NL" => "netherlands",
    "NO" => "norway",
    "PL" => "poland",
    "PT" => "portugal",
    "RO" => "romania",
    "SE" => "sweden",
    "SI" => "slovenia",
    "SK" => "slovakia",
    "TR" => "turkey",
    "UK" => "united_kingdom",
    "US" => "usa"
  }.freeze

  # Aggregate geo codes to skip (we compute our own aggregates)
  SKIP_GEO = %w[EU27_2020 EU28 EU15 EA20 EA19].freeze

  # Available datasets
  DATASETS = {
    # Annual net earnings: single person, no children, 100% average wage
    annual_net_earnings: {
      dataset: "earn_nt_net",
      params: { ecase: "P1_NCH_AW100" },
      # The estruct dimension filters: NET = net earnings, GRS = gross, TAX = taxes, SOC = social contributions
      estruct_filter: "NET",
      currencies: {
        "EUR" => { metric_suffix: "nominal", unit: "€" },
        "PPS" => { metric_suffix: "pps", unit: "PPS (EU27=100)" }
      }
    }
  }.freeze

  class << self
    # Fetch annual net earnings for all available countries and years
    #
    # @param start_year [Integer] Start year (default: 2000)
    # @param end_year [Integer] End year (default: 2024)
    # @return [Hash] { data: { "EUR" => { country => { year => value } }, "PPS" => ... }, metadata: {...} }
    def fetch_annual_net_earnings(start_year: 2000, end_year: 2024)
      config = DATASETS[:annual_net_earnings]

      # Eurostat requires repeated params for multi-value dimensions: currency=EUR&currency=PPS
      params = config[:params].merge(
        sinceTimePeriod: start_year,
        untilTimePeriod: end_year
      )

      url = build_url(config[:dataset], params) + "&currency=EUR&currency=PPS"
      Rails.logger.info "Eurostat API Request: #{url}"

      json = fetch_json(url)
      return { error: "Failed to fetch data from Eurostat" } if json.nil?

      parse_json_stat(json, config)
    rescue StandardError => e
      Rails.logger.error "Eurostat API Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { error: e.message }
    end

    # Generic fetch for any Eurostat dataset
    #
    # @param dataset_code [String] e.g. "earn_nt_net"
    # @param params [Hash] Query parameters
    # @return [Hash] Raw parsed JSON-stat data
    def fetch_dataset(dataset_code, params = {})
      url = build_url(dataset_code, params)
      Rails.logger.info "Eurostat API Request: #{url}"

      json = fetch_json(url)
      return { error: "Failed to fetch data from Eurostat" } if json.nil?

      { data: json }
    rescue StandardError => e
      Rails.logger.error "Eurostat API Error: #{e.message}"
      { error: e.message }
    end

    private

    def build_url(dataset, params)
      query = params.map { |k, v| "#{k}=#{v}" }.join("&")
      "#{BASE_URL}/#{dataset}?#{query}"
    end

    def fetch_json(url)
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 120 # Eurostat can be slow for large datasets

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "EuropeVersus/1.0"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "Eurostat HTTP Error: #{response.code} - #{response.message}"
        return nil
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      Rails.logger.error "Eurostat JSON Parse Error: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Eurostat HTTP Error: #{e.message}"
      nil
    end

    # Decode Eurostat JSON-stat flat-index format into structured data
    #
    # JSON-stat uses a flat value object where keys are stringified flat indices.
    # Each flat index encodes a position across all dimensions using strides.
    #
    # @param json [Hash] Raw JSON-stat response
    # @param config [Hash] Dataset configuration from DATASETS
    # @return [Hash] { data: { currency => { country => { year => value } } }, metadata: {...} }
    def parse_json_stat(json, config)
      dimension_ids = json["id"]     # e.g. ["freq", "currency", "estruct", "ecase", "geo", "time"]
      sizes = json["size"]           # e.g. [1, 2, 6, 1, 39, 25]
      dimensions = json["dimension"]
      values = json["value"] || {}

      # Build index→code lookup for each dimension
      dim_index = {}
      dimension_ids.each do |dim|
        cat = dimensions[dim]["category"]
        idx = cat["index"]
        # idx can be { "AT": 0, "BE": 1, ... } — invert to position→code
        dim_index[dim] = idx.invert.transform_keys(&:to_i)
      end

      # Calculate strides for flat index decoding
      strides = {}
      stride = 1
      dimension_ids.reverse_each.with_index do |dim, i|
        strides[dim] = stride
        stride *= sizes[dimension_ids.length - 1 - i]
      end

      # Filter configuration
      estruct_filter = config[:estruct_filter]
      allowed_currencies = config[:currencies].keys

      # Decode flat values into structured data
      result = {}
      allowed_currencies.each { |c| result[c] = {} }

      values.each do |flat_idx_str, value|
        next if value.nil? || value == 0

        flat_idx = flat_idx_str.to_i

        # Decode each dimension position
        decoded = {}
        dimension_ids.each_with_index do |dim, i|
          pos = (flat_idx / strides[dim]) % sizes[i]
          decoded[dim] = dim_index[dim][pos]
        end

        # Apply filters
        next if estruct_filter && decoded["estruct"] != estruct_filter
        next unless allowed_currencies.include?(decoded["currency"])

        geo_code = decoded["geo"]
        next if SKIP_GEO.include?(geo_code)

        country_key = GEO_TO_COUNTRY[geo_code]
        next unless country_key

        currency = decoded["currency"]
        year = decoded["time"].to_i
        next if year < 1900

        result[currency][country_key] ||= {}
        result[currency][country_key][year] = value.to_f
      end

      # Apply country-specific corrections
      apply_bulgaria_correction!(result)
      apply_uk_proxy!(result)

      countries_found = result.values.flat_map(&:keys).uniq.sort

      {
        data: result,
        metadata: {
          dataset: config[:dataset],
          source: "Eurostat",
          source_url: "https://ec.europa.eu/eurostat/databrowser/view/#{config[:dataset]}/default/table",
          description: json.dig("label"),
          years_available: dimension_ids.include?("time") ? dim_index["time"].values.map(&:to_i).sort : [],
          fetched_at: Time.current.iso8601
        },
        countries: countries_found
      }
    end

    # Bulgaria's EUR column in earn_nt_net actually contains BGN values.
    # Divide by the fixed peg rate to get real EUR. PPS values from Eurostat
    # are correctly computed from BGN through Eurostat's own PPP tables.
    def apply_bulgaria_correction!(result)
      bg_eur = result.dig("EUR", "bulgaria")
      return unless bg_eur&.any?

      corrected_count = 0
      bg_eur.each do |year, value|
        bg_eur[year] = (value / BGN_PER_EUR).round(2)
        corrected_count += 1
      end

      Rails.logger.info "Eurostat: Corrected #{corrected_count} Bulgaria EUR values (BGN → EUR, ÷#{BGN_PER_EUR})"
    end

    # UK stopped reporting to Eurostat after Brexit (2019 is last year).
    # For 2024, compute a proxy from ONS gross earnings, OECD tax rate, and exchange rates.
    # Formula: net_GBP = gross_GBP × (1 - avg_tax_rate/100), then convert GBP → EUR → PPS
    def apply_uk_proxy!(result)
      # Only inject if UK has no 2024 data
      return if result.dig("EUR", "united_kingdom", 2024)

      # Fetch OECD tax rate and price levels for UK
      tax_data = OecdDataService.fetch_avg_tax_rates(start_year: 2024, end_year: 2024)
      uk_tax_rate = tax_data.dig(:data, "united_kingdom", 2024)
      return unless uk_tax_rate

      price_data = OecdDataService.fetch_ppp_price_levels(start_year: 2024, end_year: 2024)
      uk_price_level = price_data.dig(:data, "united_kingdom", 2024)
      eu27_price_level = price_data.dig(:data, "eu27", 2024)
      return unless uk_price_level && eu27_price_level

      # Compute proxy: ONS gross → net → EUR → PPS
      uk_net_gbp = UK_ONS_GROSS_GBP_2024 * (1.0 - uk_tax_rate / 100.0)
      uk_net_eur = uk_net_gbp / GBP_PER_EUR_2024
      uk_net_pps = uk_net_eur * (eu27_price_level / uk_price_level)

      result["EUR"]["united_kingdom"] ||= {}
      result["EUR"]["united_kingdom"][2024] = uk_net_eur.round(2)

      result["PPS"]["united_kingdom"] ||= {}
      result["PPS"]["united_kingdom"][2024] = uk_net_pps.round(2)

      Rails.logger.info "Eurostat: Injected UK 2024 proxy — EUR: #{uk_net_eur.round(2)}, PPS: #{uk_net_pps.round(2)} " \
                        "(ONS gross £#{UK_ONS_GROSS_GBP_2024}, tax #{uk_tax_rate}%, GBP/EUR #{GBP_PER_EUR_2024})"
    end
  end
end
