require "nokogiri"

class EditionSubstackPublisher
  def initialize(edition:, base_url:, client: nil)
    @edition = edition
    @base_url = base_url.delete_suffix("/")
    @client = client
  end

  def create_draft
    require "substack"
    client = @client || authenticated_client

    post = build_post(client)
    client.post_draft(post.get_draft, publication_url: ENV["SUBSTACK_API_URL"])
  end

  def build_post(client)
    require "substack"
    post = Substack::Post.new(
      title: @edition.title,
      subtitle: @edition.dek,
      user_id: client.get_user_id
    )

    nodes = story_nodes
    append_story(post, nodes.first(1))
    post.captioned_image(
      src: "#{@base_url}/editions/#{@edition.slug}/chart.png",
      alt: @edition.chart.fetch("description"),
      caption: @edition.chart.fetch("subtitle")
    )

    append_story(post, nodes.drop(1))
    post.horizontal_rule
    post.heading("Source and method", level: 2)
    post.paragraph("#{@edition.sources.map { |source| source.fetch('name') }.join('; ')}. #{@edition.methodology}")
    post.paragraph("Explore the interactive chart and download the data: #{@base_url}/editions/#{@edition.slug}")
    post.subscribe_with_caption
    post
  end

  private

  def authenticated_client
    cookies_path = ENV.fetch("SUBSTACK_COOKIES_PATH", Rails.root.join("tmp", "substack_cookies.yml").to_s)
    options = { publication_url: ENV["SUBSTACK_API_URL"] }

    if File.exist?(cookies_path)
      options[:cookies_path] = cookies_path
    elsif ENV["SUBSTACK_EMAIL"].present? && ENV["SUBSTACK_PASSWORD"].present?
      options[:email] = ENV.fetch("SUBSTACK_EMAIL")
      options[:password] = ENV.fetch("SUBSTACK_PASSWORD")
      options[:cookies_path] = cookies_path
    else
      raise ArgumentError, "No Substack session. Set SUBSTACK_COOKIES_PATH or SUBSTACK_EMAIL and SUBSTACK_PASSWORD."
    end

    Substack::Client.new(**options)
  end

  def append_story(post, nodes)
    nodes.each do |node|
      text = node.text.gsub(/\s+/, " ").strip
      next if text.empty?

      if node.name.match?(/h[1-6]/)
        post.heading(text, level: [ node.name.delete_prefix("h").to_i, 2 ].max)
      else
        post.paragraph(text)
      end
    end
  end

  def story_nodes
    Nokogiri::HTML.fragment(@edition.render_html.to_s).children.to_a
  end
end
