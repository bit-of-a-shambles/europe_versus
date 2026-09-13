require "test_helper"

class SitemapControllerTest < ActionDispatch::IntegrationTest
  test "lists the publication and every published edition" do
    get sitemap_url(format: :xml)

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, root_url
    Edition.all.each do |edition|
      assert_includes response.body, edition_url(edition.slug)
    end
  end
end
