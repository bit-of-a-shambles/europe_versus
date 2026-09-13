require "test_helper"

class EditionsControllerTest < ActionDispatch::IntegrationTest
  test "shows the archive" do
    get editions_url

    assert_response :success
    assert_select "h1", /One chart/i
  end

  test "shows a canonical edition" do
    get edition_url("2026-09-04-europes-income-growth-moved-east")

    assert_response :success
    assert_select "figure.editorial-chart", count: 1
    assert_select ".reading-progress", count: 1
    assert_select ".reading-progress-bar", count: 1
    assert_select 'nav.primary-nav a[aria-current="page"]', "Archive"
  end

  test "exports the chart data as csv" do
    get edition_data_url("2026-09-04-europes-income-growth-moved-east")

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "country,change_percent"
  end

  test "renders each scheduled chart family and exports its plotted observations" do
    {
      "2026-09-11-productivity-gap-not-laziness" => "country,gdp_per_hour_worked_2015_usd_ppp",
      "2026-09-18-innovation-after-the-patent" => "country,applications_per_million",
      "2026-09-25-defence-spending-isnt-strategy" => "year,Europe + Canada"
    }.each do |slug, header|
      get edition_url(slug)
      assert_response :success
      assert_select "figure.editorial-chart", count: 1

      get edition_data_url(slug)
      assert_response :success
      assert_includes response.body, header
    end
  end

  test "renders a phone-first png when the browser requests an image format" do
    get edition_chart_image_url("2026-09-04-europes-income-growth-moved-east"),
      headers: { "ACCEPT" => "image/avif,image/webp,image/png,image/*" }

    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b)
    width, height = response.body.byteslice(16, 8).unpack("NN")
    assert_equal [ 1200, 3000 ], [ width, height ]
  end

  test "redirects an unknown edition" do
    get edition_url("missing")

    assert_redirected_to editions_path
  end
end
