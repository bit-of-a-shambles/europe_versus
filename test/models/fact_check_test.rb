require "test_helper"

class FactCheckTest < ActiveSupport::TestCase
  setup do
    # Ensure the content directory exists with test article
    @content_path = Rails.root.join("content", "fact_checks")
  end

  test "find returns a FactCheck for existing slug" do
    fact_check = FactCheck.find("economic-growth")

    assert_equal "economic-growth", fact_check.slug
    assert_equal "Europe's Economic Performance", fact_check.title
    assert_equal "Is Europe really falling behind?", fact_check.subtitle
    assert fact_check.published?
    assert_includes fact_check.metrics, "gdp_per_capita_ppp"
  end

  test "find raises RecordNotFound for non-existent slug" do
    assert_raises(ActiveRecord::RecordNotFound) do
      FactCheck.find("non-existent-article")
    end
  end

  test "all returns published fact checks" do
    fact_checks = FactCheck.all

    assert fact_checks.is_a?(Array)
    assert fact_checks.any? { |fc| fc.slug == "economic-growth" }
  end

  test "body contains markdown content" do
    fact_check = FactCheck.find("economic-growth")

    assert fact_check.body.present?
    assert_includes fact_check.body, "## The Decline Narrative"
    assert_includes fact_check.body, "{{metric:gdp_per_capita_ppp}}"
  end

  test "render_html converts markdown to HTML" do
    fact_check = FactCheck.find("economic-growth")

    # Create a proper view context for rendering with helpers
    lookup_context = ActionView::LookupContext.new(Rails.root.join("app", "views"))
    view_context = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)

    # Include necessary helpers
    view_context.class.include(ApplicationHelper)
    view_context.class.include(Rails.application.routes.url_helpers)

    # Stub format_value_with_unit for simpler test setup
    view_context.define_singleton_method(:format_value_with_unit) { |value, unit, _| "#{value} #{unit}" }

    html = fact_check.render_html(view_context)

    assert html.present?
    assert_includes html, "<h2"  # Markdown headers converted
    assert_includes html, "The Decline Narrative"
  end

  test "metric_data returns data for referenced metrics" do
    # Ensure test metrics exist
    Metric.find_or_create_by!(
      country: "europe",
      metric_name: "gdp_per_capita_ppp",
      year: 2023
    ) do |m|
      m.metric_value = 52000
      m.unit = "International $ (PPP)"
      m.source = "Our World in Data"
    end

    fact_check = FactCheck.find("economic-growth")
    data = fact_check.metric_data

    assert data.key?("gdp_per_capita_ppp")
    assert data["gdp_per_capita_ppp"][:europe].present?
  end
end
