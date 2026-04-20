# FactCheck - A PORO model for loading markdown-based fact-check articles
#
# Articles are stored as markdown files with YAML frontmatter in content/fact_checks/
# Custom tags are processed to embed live data:
#   {{metric:metric_name}} - Renders a metric comparison card
#   {{chart:metric_name}}  - Renders a link to our interactive statistics chart
#
# Example:
#   fact_check = FactCheck.find("economic-growth")
#   fact_check.title       # => "Europe's Economic Performance"
#   fact_check.render_html # => Processed HTML with embedded components

require "yaml"
require "kramdown"

class FactCheck
  CONTENT_PATH = Rails.root.join("content", "fact_checks")

  attr_reader :slug, :title, :subtitle, :description, :og_description,
              :metrics, :published, :created_at, :updated_at, :body,
              :claim, :verdict_rating, :verdict_summary, :tweets, :quick_stats,
              :section_summaries

  def initialize(slug, frontmatter, body)
    @slug = slug
    @title = frontmatter["title"]
    @subtitle = frontmatter["subtitle"]
    @description = frontmatter["description"]
    @og_description = frontmatter["og_description"] || @description
    @metrics = frontmatter["metrics"] || []
    @published = frontmatter.fetch("published", true)
    @created_at = frontmatter["created_at"]
    @updated_at = frontmatter["updated_at"]
    @claim = frontmatter["claim"]
    @verdict_rating = frontmatter["verdict_rating"]
    @verdict_summary = frontmatter["verdict_summary"]
    @tweets = frontmatter["tweets"] || []
    @quick_stats = frontmatter["quick_stats"] || []
    @section_summaries = frontmatter["section_summaries"] || {}
    @body = body
  end

  # Find a fact check by slug
  def self.find(slug)
    file_path = CONTENT_PATH.join("#{slug}.md")
    raise ActiveRecord::RecordNotFound, "FactCheck '#{slug}' not found" unless File.exist?(file_path)

    parse_file(file_path, slug)
  end

  # List all published fact checks
  def self.all
    return [] unless CONTENT_PATH.exist?

    Dir.glob(CONTENT_PATH.join("*.md")).filter_map do |file_path|
      slug = File.basename(file_path, ".md")
      fact_check = parse_file(file_path, slug)
      fact_check if fact_check.published?
    end.sort_by { |fc| fc.created_at || Time.now }.reverse
  end

  def published?
    @published
  end

  # Rating configuration shared by model and views
  RATING_CONFIG = {
    "false" => { label: "False", color: "#DC2626", icon: "✗" },
    "mostly_false" => { label: "Mostly False", color: "#EA580C", icon: "⚠" },
    "mixed" => { label: "Mixed", color: "#CA8A04", icon: "◐" },
    "mostly_true" => { label: "Mostly True", color: "#0066FF", icon: "◑" },
    "true" => { label: "True", color: "#16A34A", icon: "✓" }
  }.freeze

  def verdict_config
    RATING_CONFIG[@verdict_rating] || RATING_CONFIG["mixed"]
  end

  # Render the markdown body to HTML, processing custom tags
  def render_html(view_context)
    # Pre-process: Replace verdict tags with placeholders before Kramdown
    # (to prevent | from being interpreted as table syntax)
    body_with_placeholders, verdict_placeholders = preprocess_verdict_tags(@body)

    # First pass: convert markdown to HTML
    html = Kramdown::Document.new(body_with_placeholders, input: "GFM", syntax_highlighter: nil).to_html

    # Second pass: process custom tags
    html = process_metric_tags(html, view_context)
    html = process_chart_tags(html, view_context)

    # Restore verdict placeholders with rendered partials
    html = restore_verdict_placeholders(html, verdict_placeholders, view_context)

    # Wrap tables in responsive container
    html = wrap_tables_for_responsive(html)

    # Wrap H2 sections in collapsible accordion elements (server-side, no JS)
    html = wrap_sections_in_accordions(html)

    html.html_safe
  end

  # European regional groupings for comparison
  EUROPEAN_REGIONS = {
    europe: { name: "Europe", flag: "🇪🇺", description: "All European countries" },
    european_union: { name: "EU-27", flag: "🇪🇺", description: "European Union member states" },
    core_eu: { name: "Core EU", flag: "🇪🇺", description: "Founding members (DE, FR, IT, NL, BE, LU)" },
    eurozone: { name: "Eurozone", flag: "💶", description: "Countries using the Euro" },
    non_euro_eu: { name: "Non-€ EU", flag: "🇪🇺", description: "EU members not using the Euro" },
    non_eu_europe: { name: "Non-EU", flag: "🌍", description: "European countries outside the EU" }
  }.freeze

  # Get metric data for all referenced metrics, including multiple European groupings
  def metric_data
    @metric_data ||= @metrics.each_with_object({}) do |metric_name, data|
      latest_year = Metric.where(metric_name: metric_name).maximum(:year)
      next unless latest_year

      # Load all European regional aggregates
      european_data = {}
      EUROPEAN_REGIONS.keys.each do |region_key|
        european_data[region_key] = Metric.find_by(
          metric_name: metric_name,
          country: region_key.to_s,
          year: latest_year
        )
      end

      data[metric_name] = {
        # European regions
        **european_data,
        # Global comparisons
        usa: Metric.find_by(metric_name: metric_name, country: "usa", year: latest_year),
        china: Metric.find_by(metric_name: metric_name, country: "china", year: latest_year),
        india: Metric.find_by(metric_name: metric_name, country: "india", year: latest_year),
        year: latest_year,
        config: metric_config(metric_name)
      }
    end
  end

  private

  def self.parse_file(file_path, slug)
    content = File.read(file_path)

    # Split frontmatter and body
    if content =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
      frontmatter = YAML.safe_load(::Regexp.last_match(1), permitted_classes: [ Date, Time ])
      body = ::Regexp.last_match(2)
    else
      frontmatter = {}
      body = content
    end

    new(slug, frontmatter, body)
  end

  def process_metric_tags(html, view_context)
    html.gsub(/\{\{metric:(\w+)\}\}/) do |_match|
      metric_name = ::Regexp.last_match(1)
      data = metric_data[metric_name]

      if data
        view_context.render(
          partial: "fact_checks/metric_card",
          locals: { metric_name: metric_name, data: data }
        )
      else
        %(<div class="text-red-500 p-4 border border-red-500">Metric not found: #{metric_name}</div>)
      end
    end
  end

  def process_chart_tags(html, view_context)
    html.gsub(/\{\{chart:([a-z0-9_-]+)(\?[^}]+)?\}\}/) do |_match|
      metric_slug = ::Regexp.last_match(1)
      options_string = ::Regexp.last_match(2)

      # Parse options from query string format
      options = {}
      if options_string
        # Unescape HTML entities that Kramdown may have encoded
        unescaped_options = CGI.unescapeHTML(options_string[1..])
        unescaped_options.split("&").each do |pair|
          key, value = pair.split("=")
          options[key.to_sym] = value
        end
      end

      view_context.render(
        partial: "fact_checks/statistic_link",
        locals: { metric_slug: metric_slug, chart_options: options }
      )
    end
  end

  def preprocess_verdict_tags(body)
    placeholders = {}
    counter = 0

    processed_body = body.gsub(/\{\{verdict:([a-z_]+)\|([^}]+)\}\}/) do |_match|
      rating = ::Regexp.last_match(1)
      summary = ::Regexp.last_match(2)

      placeholder = "VERDICT_PLACEHOLDER_#{counter}"
      placeholders[placeholder] = { rating: rating, summary: summary }
      counter += 1

      placeholder
    end

    [ processed_body, placeholders ]
  end

  def restore_verdict_placeholders(html, placeholders, view_context)
    placeholders.each do |placeholder, data|
      rendered = view_context.render(
        partial: "fact_checks/fact_check_verdict",
        locals: { rating: data[:rating], summary: data[:summary] }
      )
      html = html.gsub(/<p>#{placeholder}<\/p>|#{placeholder}/, rendered)
    end
    html
  end

  def wrap_tables_for_responsive(html)
    # Wrap standalone tables in a responsive wrapper div
    html.gsub(/<table>/, '<div class="table-wrapper"><table>').gsub(/<\/table>/, "</table></div>")
  end

  def wrap_sections_in_accordions(html)
    # Split at each <h2> boundary (keeping the h2 with its following content)
    parts = html.split(/(?=<h2[\s>])/)
    return html if parts.length <= 1

    result = parts.first.to_s

    parts.drop(1).each do |section|
      h2_match = section.match(/<h2[^>]*>(.*?)<\/h2>/mi)
      unless h2_match
        result += section
        next
      end

      title_plain = h2_match[1].gsub(/<[^>]+>/, "").strip

      # Skip the "Our Verdict" section — the verdict card is already rendered at the top of the page
      if title_plain.downcase.include?("verdict")
        next
      end

      summary_text = section_summaries[title_plain].to_s
      content_after_h2 = section[h2_match.end(0)..]

      summary_para = summary_text.present? ? %(<p class="fact-check-section-preview">#{ERB::Util.html_escape(summary_text)}</p>) : ""

      result += <<~HTML
        <details class="fact-check-section">
          <summary class="fact-check-section-summary">
            <div class="fact-check-section-heading">#{title_plain}</div>
            #{summary_para}
          </summary>
          <div class="fact-check-section-body">
            #{content_after_h2}
          </div>
        </details>
      HTML
    end

    result
  end

  def metric_config(metric_name)
    config = nil
    config = MetricImporter.configs[metric_name] if defined?(MetricImporter)
    config ||= OwidMetricImporter.all_configs[metric_name] if defined?(OwidMetricImporter)
    config || {}
  end
end
