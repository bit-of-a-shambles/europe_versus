require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # format_metric_value tests
  test "format_metric_value returns em dash for nil value" do
    assert_equal "\u2014", format_metric_value(nil, {})
  end

  test "format_metric_value formats currency values" do
    metadata = { format: "currency" }
    assert_equal "$50,000", format_metric_value(50000, metadata)
    assert_equal "$1,234,567", format_metric_value(1234567, metadata)
  end

  test "format_metric_value formats decimal values with specified precision" do
    metadata = { format: "decimal", decimals: 2 }
    assert_equal "12.35", format_metric_value(12.345, metadata)

    metadata = { format: "decimal", decimals: 1 }
    assert_equal "12.3", format_metric_value(12.345, metadata)
  end

  test "format_metric_value formats percentage values" do
    metadata = { format: "percentage", decimals: 1 }
    assert_equal "12.5%", format_metric_value(12.5, metadata)

    metadata = { format: "percentage", decimals: 2 }
    assert_equal "99.99%", format_metric_value(99.99, metadata)
  end

  test "format_metric_value formats integer values with delimiters" do
    metadata = { format: "integer" }
    assert_equal "1,234,567", format_metric_value(1234567, metadata)
  end

  test "format_metric_value uses integer as default format" do
    assert_equal "1,234,567", format_metric_value(1234567, {})
  end

  test "format_metric_value handles unknown format types" do
    metadata = { format: "unknown_format" }
    assert_equal "12345", format_metric_value(12345, metadata)
  end

  # format_value_with_unit tests
  test "format_value_with_unit returns em dash for nil value" do
    assert_equal "\u2014", format_value_with_unit(nil, "%")
  end

  test "format_value_with_unit formats percentage values" do
    assert_equal "12.50%", format_value_with_unit(12.5, "%")
    assert_equal "99.00%", format_value_with_unit(99, "percent")
  end

  test "format_value_with_unit formats small currency values with precision" do
    assert_equal "$99.50", format_value_with_unit(99.5, "international $")
  end

  test "format_value_with_unit formats large currency values with delimiters" do
    assert_equal "$50,000", format_value_with_unit(50000, "USD")
    assert_equal "$1,234,567", format_value_with_unit(1234567, "PPP dollars")
  end

  test "format_value_with_unit formats score-based values" do
    assert_equal "7.50", format_value_with_unit(7.5, "score (0-10)")
  end

  test "format_value_with_unit formats rate values" do
    assert_equal "5.25", format_value_with_unit(5.25, "per 1,000")
    assert_equal "3.00", format_value_with_unit(3, "per million")
    assert_equal "12.50", format_value_with_unit(12.5, "per 100")
  end

  test "format_value_with_unit formats years" do
    assert_equal "82.5 years", format_value_with_unit(82.5, "years")
  end

  test "format_value_with_unit formats people/population" do
    assert_equal "1,000,000", format_value_with_unit(1000000, "people")
    assert_equal "500,000", format_value_with_unit(500000, "population")
  end

  test "format_value_with_unit formats births per woman" do
    assert_equal "1.75", format_value_with_unit(1.75, "births per woman")
  end

  test "format_value_with_unit handles small numbers with default formatting" do
    assert_equal "5.50", format_value_with_unit(5.5, "unknown_unit")
  end

  test "format_value_with_unit handles large numbers with default formatting" do
    assert_equal "1,000", format_value_with_unit(1000, "unknown_unit")
  end

  test "format_value_with_unit handles non-numeric values" do
    assert_equal "some_string", format_value_with_unit("some_string", "unknown")
  end

  # should_show_decimals? tests
  test "should_show_decimals? returns true for percentage values under 10" do
    assert should_show_decimals?(5, "%")
    assert should_show_decimals?(9.9, "%")
  end

  test "should_show_decimals? returns false for percentage values 10 or over" do
    refute should_show_decimals?(10, "%")
    refute should_show_decimals?(50, "%")
  end

  test "should_show_decimals? returns false for non-percentage values" do
    refute should_show_decimals?(5, "USD")
    refute should_show_decimals?(5, nil)
  end

  # growth_rate_color_class tests
  test "growth_rate_color_class returns slate for nil growth rate" do
    assert_equal "text-slate-600", growth_rate_color_class(nil, {})
  end

  test "growth_rate_color_class returns slate for zero growth rate" do
    assert_equal "text-slate-600", growth_rate_color_class(0, {})
  end

  test "growth_rate_color_class returns slate when higher_is_better is nil" do
    assert_equal "text-slate-600", growth_rate_color_class(5, {})
    assert_equal "text-slate-600", growth_rate_color_class(-5, {})
  end

  test "growth_rate_color_class returns green for positive growth when higher is better" do
    metadata = { higher_is_better: true }
    assert_equal "text-green-600", growth_rate_color_class(5, metadata)
  end

  test "growth_rate_color_class returns red for negative growth when higher is better" do
    metadata = { higher_is_better: true }
    assert_equal "text-red-600", growth_rate_color_class(-5, metadata)
  end

  test "growth_rate_color_class returns green for negative growth when lower is better" do
    metadata = { higher_is_better: false }
    assert_equal "text-green-600", growth_rate_color_class(-5, metadata)
  end

  test "growth_rate_color_class returns red for positive growth when lower is better" do
    metadata = { higher_is_better: false }
    assert_equal "text-red-600", growth_rate_color_class(5, metadata)
  end
end
