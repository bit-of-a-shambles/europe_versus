require "test_helper"

class FactChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure we have test metrics in the database for the article
    @metric_name = "gdp_per_capita_ppp"
    @year = 2023

    [ "europe", "usa", "china", "india" ].each do |country|
      Metric.find_or_create_by!(
        country: country,
        metric_name: @metric_name,
        year: @year
      ) do |m|
        m.metric_value = { "europe" => 52000, "usa" => 76000, "china" => 23000, "india" => 9000 }[country]
        m.unit = "International $ (PPP)"
        m.source = "Our World in Data"
      end
    end
  end

  test "should get index" do
    get facts_url
    assert_response :success
    assert_select "h1", /FACT/
  end

  test "should get show for existing article" do
    get fact_check_url(slug: "economic-growth")
    assert_response :success
    assert_select "h1", /Economic Performance/i
  end

  test "should redirect to index for non-existent article" do
    get fact_check_url(slug: "non-existent-article")
    assert_redirected_to facts_path
    assert_equal "Article not found", flash[:alert]
  end

  test "show page includes Open Graph meta tags" do
    get fact_check_url(slug: "economic-growth")
    assert_response :success

    assert_select 'meta[property="og:title"]'
    assert_select 'meta[property="og:image"]'
    assert_select 'meta[name="twitter:card"]'
  end

  test "show page includes share buttons" do
    get fact_check_url(slug: "economic-growth")
    assert_response :success

    # Check for share links
    assert_select 'a[href*="twitter.com/intent/tweet"]'
    assert_select 'a[href*="linkedin.com/sharing"]'
  end

  test "show page renders metric cards" do
    get fact_check_url(slug: "economic-growth")
    assert_response :success

    # Check that metric data is rendered (the metric_card partial)
    assert_match(/Data Point/i, response.body)
  end

  test "should get embed" do
    get embed_fact_url(slug: "economic-growth")
    assert_response :success
    assert_select ".card"
  end

  test "index shows article cards when articles exist" do
    get facts_url
    assert_response :success

    # Should show the economic-growth article
    assert_match(/Economic/i, response.body)
  end
end
