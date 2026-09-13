xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  xml.url do
    xml.loc root_url
    xml.changefreq "weekly"
    xml.priority "1.0"
  end

  xml.url do
    xml.loc editions_url
    xml.changefreq "weekly"
    xml.priority "0.8"
  end

  xml.url do
    xml.loc methodology_url
    xml.changefreq "monthly"
    xml.priority "0.5"
  end

  @editions.each do |edition|
    xml.url do
      xml.loc edition_url(edition.slug)
      xml.lastmod edition.published_at.iso8601
      xml.changefreq "never"
      xml.priority "0.9"
    end
  end
end
