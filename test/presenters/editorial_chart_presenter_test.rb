require "test_helper"

class EditorialChartPresenterTest < ActiveSupport::TestCase
  test "builds a sorted, directly labelled country ranking" do
    chart = EditorialChartPresenter.new(Edition.latest)

    assert_equal "ranked_bar", chart.type
    assert_equal 26, chart.series.size
    assert_equal [ "Romania", "Lithuania", "Poland" ], chart.series.first(3).map(&:label)
    assert_equal "+134%", chart.formatted_value(chart.ranked_value(chart.series.first))
    assert_equal "-5%", chart.formatted_value(chart.ranked_value(chart.series.last))
  end

  test "supports the launch month chart families and stable csv data" do
    expectations = {
      "2026-09-11-productivity-gap-not-laziness" => [ "ranked_bar", 38 ],
      "2026-09-18-innovation-after-the-patent" => [ "ranked_bar", 21 ],
      "2026-09-25-defence-spending-isnt-strategy" => [ "line", 12 ]
    }

    expectations.each do |slug, (type, row_count)|
      chart = EditorialChartPresenter.new(Edition.find(slug))

      assert_equal type, chart.type
      assert_equal row_count, chart.csv_rows.size
      refute chart.empty?
    end
  end
end
