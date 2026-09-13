require "json"
require "nokogiri"
require "open3"
require "zip"

module LaunchMonthVerification
  module_function

  RAW = Rails.root.join("analysis", "launch_month", "raw")

  EUROSTAT_CODES = {
    "belgium" => "BE", "czechia" => "CZ", "denmark" => "DK", "germany" => "DE",
    "estonia" => "EE", "ireland" => "IE", "greece" => "EL", "spain" => "ES",
    "france" => "FR", "croatia" => "HR", "italy" => "IT", "cyprus" => "CY",
    "latvia" => "LV", "lithuania" => "LT", "luxembourg" => "LU", "hungary" => "HU",
    "malta" => "MT", "netherlands" => "NL", "austria" => "AT", "poland" => "PL",
    "portugal" => "PT", "romania" => "RO", "slovenia" => "SI", "slovakia" => "SK",
    "finland" => "FI", "sweden" => "SE"
  }.freeze

  OECD_CODES = {
    "australia" => "AUS", "austria" => "AUT", "belgium" => "BEL", "canada" => "CAN",
    "switzerland" => "CHE", "colombia" => "COL", "costa_rica" => "CRI", "czechia" => "CZE",
    "germany" => "DEU", "denmark" => "DNK", "spain" => "ESP", "estonia" => "EST",
    "eu27" => "EU27", "finland" => "FIN", "france" => "FRA", "united_kingdom" => "GBR",
    "greece" => "GRC", "hungary" => "HUN", "ireland" => "IRL", "iceland" => "ISL",
    "israel" => "ISR", "italy" => "ITA", "japan" => "JPN", "south_korea" => "KOR",
    "lithuania" => "LTU", "luxembourg" => "LUX", "latvia" => "LVA", "mexico" => "MEX",
    "netherlands" => "NLD", "norway" => "NOR", "new_zealand" => "NZL", "oecd" => "OECD",
    "poland" => "POL", "portugal" => "PRT", "slovakia" => "SVK", "slovenia" => "SVN",
    "sweden" => "SWE", "united_states" => "USA"
  }.freeze

  EPO_NAMES = {
    "south_korea" => "Republic of Korea", "united_states" => "United States",
    "united_kingdom" => "United Kingdom", "hong_kong" => "Hong Kong SAR",
    "eu27" => "EU27 states"
  }.freeze

  def run
    verify_household_income
    verify_productivity_levels
    verify_patent_intensity
    verify_defence_spending
    puts "Launch month verification passed."
  end

  def verify_household_income
    edition = Edition.find("2026-09-04-europes-income-growth-moved-east")
    chart = EditorialChartPresenter.new(edition)
    payload = JSON.parse(File.read(RAW.join("eurostat_household_income_2004_2024.json")))
    geo_positions = payload.dig("dimension", "geo", "category", "index")
    time_positions = payload.dig("dimension", "time", "category", "index")
    values = payload.fetch("value")

    chart.series.each do |series|
      geo = geo_positions.fetch(EUROSTAT_CODES.fetch(series.key))
      first = values.fetch((geo * 2 + time_positions.fetch("2004")).to_s)
      last = values.fetch((geo * 2 + time_positions.fetch("2024")).to_s)
      change = ((last / first - 1) * 100).round
      assert_close(change, chart.ranked_value(series), "Eurostat #{series.label} change")
    end

    article = Nokogiri::HTML(File.read(RAW.join("eurostat_household_income_article.html"))).text.gsub(/\s+/, " ")
    raise "Eurostat's published EU aggregate changed" unless article.match?(/(?:grew|up) by?\s*22%/i) || article.match?(/up 22%/i)
    puts "01 household income: 26 country changes and EU +22% aggregate verified"
  end

  def verify_productivity_levels
    edition = Edition.find("2026-09-11-productivity-gap-not-laziness")
    chart = EditorialChartPresenter.new(edition)
    rows = xlsx_rows(RAW.join("oecd_productivity_2024.xlsx"), 1)
    source = rows.filter_map do |row|
      next unless row[1] && row[2]&.match?(/\A\d/)

      [ row[1], row[2].to_f ]
    end.to_h

    chart.series.each do |series|
      code = OECD_CODES.fetch(series.key)
      assert_close(source.fetch(code), chart.ranked_value(series), "OECD #{series.label}")
    end

    us = source.fetch("USA")
    eu = source.fetch("EU27")
    assert_close((us - eu) / us * 100, 24.65, "EU productivity gap", tolerance: 0.01)
    puts "02 productivity: all 38 OECD figure rows verified; EU gap is #{format('%.1f', (us - eu) / us * 100)}%"
  end

  def verify_patent_intensity
    edition = Edition.find("2026-09-18-innovation-after-the-patent")
    chart = EditorialChartPresenter.new(edition)
    rows = xlsx_rows(RAW.join("epo_patent_applications_2025.xlsx"), 10)
    source = rows.filter_map do |row|
      next unless row[1] && row[4]&.match?(/\A\d/)

      [ row[1], row[4].to_f ]
    end.to_h

    chart.series.each do |series|
      name = EPO_NAMES.fetch(series.key, series.label)
      assert_close(source.fetch(name), chart.ranked_value(series), "EPO #{series.label}", tolerance: 0.001)
    end
    raise "EPO ranking is not descending" unless chart.series.map { |series| chart.ranked_value(series) }.each_cons(2).all? { |a, b| a >= b }
    puts "03 patents: 20 country origins and EU-27 aggregate verified against EPO workbook"
  end

  def verify_defence_spending
    edition = Edition.find("2026-09-25-defence-spending-isnt-strategy")
    chart = EditorialChartPresenter.new(edition)
    pdf = RAW.join("nato_defence_expenditure_2025.pdf").to_s
    text, error, status = Open3.capture3("pdftotext", "-layout", pdf, "-")
    raise "pdftotext failed: #{error}" unless status.success?

    row = text.lines.find do |line|
      line.include?("NATO Europe and Canada") && line.include?("1.40") && line.include?("2.27")
    end
    raise "NATO GDP-share row not found" unless row

    observed = row.scan(/\d+\.\d+/).map(&:to_f)
    expected = chart.series.first.values.sort.map(&:last)
    raise "Expected 12 NATO annual observations" unless observed.length == 12
    observed.zip(expected).each_with_index do |(actual, value), index|
      assert_close(actual, value, "NATO #{2014 + index}")
    end

    page = Nokogiri::HTML(File.read(RAW.join("nato_defence_commitment_2026.html"))).text.gsub(/\s+/, " ")
    raise "NATO 2025 total no longer found" unless page.match?(/more than (?:USD|\$) 571 billion/i)
    raise "NATO annual increase no longer found" unless page.match?(/over (?:USD|\$) 90 billion/i)
    puts "04 defence: 12 annual GDP shares plus $571bn and $90bn summary claims verified"
  end

  def xlsx_rows(path, sheet_number)
    Zip::File.open(path) do |archive|
      shared = if archive.find_entry("xl/sharedStrings.xml")
        xml = Nokogiri::XML(archive.read("xl/sharedStrings.xml"))
        xml.remove_namespaces!
        xml.xpath("//si").map { |node| node.xpath(".//t").map(&:text).join }
      else
        []
      end

      xml = Nokogiri::XML(archive.read("xl/worksheets/sheet#{sheet_number}.xml"))
      xml.remove_namespaces!
      xml.xpath("//sheetData/row").map do |row|
        values = []
        row.xpath("./c").each do |cell|
          column = cell["r"][/[A-Z]+/]
          index = column.each_byte.reduce(0) { |sum, byte| sum * 26 + byte - 64 } - 1
          raw = cell.at_xpath("./v")&.text
          values[index] = cell["t"] == "s" && raw ? shared.fetch(raw.to_i) : raw
        end
        values
      end
    end
  end

  def assert_close(actual, expected, label, tolerance: 0.0001)
    raise "Missing #{label}" if actual.nil?
    return if (actual.to_f - expected.to_f).abs <= tolerance

    raise "#{label}: expected #{expected}, received #{actual}"
  end
end

LaunchMonthVerification.run
