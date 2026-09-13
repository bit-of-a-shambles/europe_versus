require "yaml"
require "kramdown"

class Edition
  CONTENT_PATH = Rails.root.join("content", "editions")

  attr_reader :slug, :title, :dek, :issue_number, :published_at, :category,
    :chart, :source, :sources, :geography, :methodology, :published, :body,
    :substack

  def initialize(slug, frontmatter, body)
    @slug = slug
    @title = frontmatter.fetch("title")
    @dek = frontmatter.fetch("dek")
    @issue_number = frontmatter.fetch("issue_number")
    @published_at = frontmatter.fetch("published_at")
    @category = frontmatter.fetch("category")
    @chart = frontmatter.fetch("chart")
    @sources = frontmatter["sources"] || [ frontmatter.fetch("source") ]
    @source = @sources.first
    @geography = frontmatter.fetch("geography")
    @methodology = frontmatter.fetch("methodology")
    @published = frontmatter.fetch("published", true)
    @substack = frontmatter.fetch("substack", {})
    @body = body
  end

  def self.find(slug)
    path = CONTENT_PATH.join("#{slug}.md")
    raise ActiveRecord::RecordNotFound, "Edition '#{slug}' not found" unless path.exist?

    parse(path, slug)
  end

  def self.all
    return [] unless CONTENT_PATH.exist?

    Dir.glob(CONTENT_PATH.join("*.md")).filter_map do |path|
      edition = parse(path, File.basename(path, ".md"))
      edition if edition.published?
    end.sort_by(&:published_at).reverse
  end

  def self.latest
    all.first || raise(ActiveRecord::RecordNotFound, "No published editions")
  end

  def published?
    @published
  end

  def render_html
    Kramdown::Document.new(@body, input: "GFM", syntax_highlighter: nil).to_html.html_safe
  end

  private

  def self.parse(path, slug)
    content = File.read(path)
    match = content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)
    raise ArgumentError, "Edition '#{slug}' needs YAML frontmatter" unless match

    frontmatter = YAML.safe_load(match[1], permitted_classes: [ Date, Time ])
    new(slug, frontmatter, match[2])
  end
end
