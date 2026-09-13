require "test_helper"

class EditionTest < ActiveSupport::TestCase
  test "loads published editions from frontmatter" do
    edition = Edition.latest

    assert_equal 1, edition.issue_number
    assert_equal "Economy", edition.category
    assert_equal "26 EU countries with comparable observations", edition.geography
    assert_equal "real_household_income_change", edition.chart.fetch("metric")
  end

  test "renders the reported story as html" do
    html = Edition.latest.render_html

    assert_includes html, "American shorthand"
    assert_includes html, "<strong>"
  end

  test "raises for an unknown edition" do
    assert_raises(ActiveRecord::RecordNotFound) { Edition.find("missing") }
  end

  test "loads scheduled launch editions without adding them to the public archive" do
    edition = Edition.find("2026-09-18-innovation-after-the-patent")

    assert_equal 3, edition.issue_number
    assert_equal 2, edition.sources.size
    assert_equal "Europe does not lack invention. It loses too much ground between invention and scale.", edition.substack.fetch("preview_text")
    refute edition.published?
    refute_includes Edition.all.map(&:slug), edition.slug
  end
end
