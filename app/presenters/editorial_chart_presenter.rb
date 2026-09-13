class EditorialChartPresenter
  Series = Struct.new(:key, :label, :color, :values, :highlight, :options, keyword_init: true)
  Point = Struct.new(:key, :label, :x_value, :y_value, :highlight, :options, keyword_init: true)

  WIDTH = 1_080.0
  HEIGHT = 610.0
  PLOT = { left: 72.0, right: 890.0, top: 54.0, bottom: 532.0 }.freeze
  COMPACT_PLOT = { left: 48.0, right: 515.0, top: 34.0, bottom: 315.0 }.freeze

  MOBILE_WIDTH = 360.0
  MOBILE_PLOTS = {
    "line" => { left: 38.0, right: 282.0, top: 28.0, bottom: 258.0 },
    "dumbbell" => { left: 78.0, right: 340.0, top: 48.0, bottom: 382.0 },
    "scatter" => { left: 42.0, right: 342.0, top: 28.0, bottom: 350.0 }
  }.freeze
  MOBILE_HEIGHTS = {
    "line" => 305.0,
    "dumbbell" => 430.0,
    "scatter" => 410.0,
    "small_multiples" => 760.0
  }.freeze

  attr_reader :edition

  def initialize(edition)
    @edition = edition
  end

  def type
    specification.fetch("type", "line").to_s.tr("-", "_")
  end

  def image_height
    specification.fetch("image_height", 1_500).to_i
  end

  def desktop_height
    return specification.fetch("desktop_height", 110 + series.length * 27).to_f if type == "ranked_bar"

    type == "small_multiples" ? 650.0 : HEIGHT
  end

  def mobile_height
    return specification.fetch("mobile_height", 88 + series.length * 24).to_f if type == "ranked_bar"

    MOBILE_HEIGHTS.fetch(type, 360.0)
  end

  def period_label
    specification.fetch("period_label", start_year == end_year ? start_year.to_s : "#{start_year}–#{end_year}")
  end

  def series
    @series ||= specification.fetch("series", []).map do |item|
      values = if item["values"]
        item.fetch("values").to_h do |observation|
          [ observation.fetch("year").to_i, observation.fetch("value").to_f ]
        end
      else
        Metric.where(
          metric_name: specification.fetch("metric"),
          country: item.fetch("key"),
          year: start_year..end_year
        ).order(:year).to_h { |record| [ record.year, record.metric_value.to_f ] }
      end

      Series.new(
        key: item.fetch("key"),
        label: item.fetch("label"),
        color: item.fetch("color", "#67635D"),
        values: values,
        highlight: item.fetch("highlight", false),
        options: item
      )
    end
  end

  def points
    @points ||= specification.fetch("points", []).map do |item|
      Point.new(
        key: item.fetch("key"),
        label: item.fetch("label"),
        x_value: item.fetch("x").to_f,
        y_value: item.fetch("y").to_f,
        highlight: item.fetch("highlight", false),
        options: item
      )
    end
  end

  def empty?
    type == "scatter" ? points.empty? : series.all? { |item| item.values.empty? }
  end

  def start_year
    specification.fetch("start_year", series.flat_map { |item| item.values.keys }.min).to_i
  end

  def end_year
    specification.fetch("end_year", series.flat_map { |item| item.values.keys }.max).to_i
  end

  def x_ticks
    interval = specification.fetch("x_tick_interval", 5).to_i
    (start_year..end_year).select { |year| (year - start_year) % interval == 0 || year == end_year }
  end

  def compact_x_ticks
    [ start_year, start_year + ((end_year - start_year) / 2), end_year ].uniq
  end

  def compact_x(year)
    scale(year, start_year, end_year, COMPACT_PLOT[:left], COMPACT_PLOT[:right])
  end

  def compact_y(value)
    scale(value, y_domain.first, y_domain.last, COMPACT_PLOT[:bottom], COMPACT_PLOT[:top])
  end

  def compact_path_for(item)
    item.values.sort.map.with_index do |(year, value), index|
      command = index.zero? ? "M" : "L"
      "#{command} #{compact_x(year).round(2)} #{compact_y(value).round(2)}"
    end.join(" ")
  end

  def compact_gap_area_path
    first, second = series
    return "" unless first && second

    common_years = (first.values.keys & second.values.keys).sort
    return "" if common_years.empty?

    forward = common_years.map { |year| "#{compact_x(year).round(2)} #{compact_y(first.values[year]).round(2)}" }
    backward = common_years.reverse.map { |year| "#{compact_x(year).round(2)} #{compact_y(second.values[year]).round(2)}" }
    "M #{forward.join(' L ')} L #{backward.join(' L ')} Z"
  end

  def y_ticks
    return specification.fetch("y_ticks").map(&:to_f) if specification["y_ticks"]

    min, max = y_domain
    step = specification.fetch("y_tick_interval", 10).to_f
    values = []
    current = min
    while current <= max
      values << current
      current += step
    end
    values
  end

  def compact_y_ticks
    ticks = y_ticks
    ticks.select.with_index { |_tick, index| index.even? || ticks.length <= 4 }
  end

  def y_domain
    specification.fetch("y_domain").map(&:to_f)
  end

  def x_domain
    (specification["x_domain"] || y_domain).map(&:to_f)
  end

  def x(year, layout: :desktop)
    plot = plot_for(layout)
    scale(year, start_year, end_year, plot[:left], plot[:right])
  end

  def y(value, layout: :desktop)
    plot = plot_for(layout)
    scale(value, y_domain.first, y_domain.last, plot[:bottom], plot[:top])
  end

  def path_for(item, layout: :desktop)
    item.values.sort.map.with_index do |(year, value), index|
      command = index.zero? ? "M" : "L"
      "#{command} #{x(year, layout: layout).round(2)} #{y(value, layout: layout).round(2)}"
    end.join(" ")
  end

  def gap_area_path(layout: :desktop)
    first, second = series
    return "" unless first && second

    common_years = (first.values.keys & second.values.keys).sort
    return "" if common_years.empty?

    forward = common_years.map { |year| "#{x(year, layout: layout).round(2)} #{y(first.values[year], layout: layout).round(2)}" }
    backward = common_years.reverse.map { |year| "#{x(year, layout: layout).round(2)} #{y(second.values[year], layout: layout).round(2)}" }
    "M #{forward.join(' L ')} L #{backward.join(' L ')} Z"
  end

  def latest_value(item)
    item.values[end_year] || item.values.values.last
  end

  def latest_year(item)
    item.values.key?(end_year) ? end_year : item.values.keys.last
  end

  def formatted_value(value)
    case specification.fetch("value_format", "currency_zero")
    when "percent_one"
      "#{format('%.1f', value)}%"
    when "percent_zero_signed"
      value.zero? ? "0%" : "#{format('%+d', value.round)}%"
    when "currency_one"
      "$#{format('%.1f', value)}"
    when "decimal_two"
      format("%.2f", value)
    when "decimal_one"
      format("%.1f", value)
    when "integer"
      number_with_delimiter(value.round)
    else
      "$#{number_with_delimiter(value.round)}"
    end
  end

  def formatted_tick(value, axis: :y)
    if type == "scatter"
      return "#{value.to_i}%" if axis == :x
      return value.zero? ? "0" : "#{(value / 1_000).round}k"
    end

    case specification.fetch("value_format", "currency_zero")
    when "percent_one"
      "#{format('%.1f', value)}%"
    when "percent_zero_signed"
      value.zero? ? "0%" : "#{format('%+d', value.round)}%"
    when "currency_one"
      "$#{value.round}"
    when "decimal_two", "decimal_one"
      format("%.1f", value)
    when "integer"
      number_with_delimiter(value.round)
    else
      "$#{value.to_i}"
    end
  end

  def gap(layout: :desktop)
    return nil unless type == "line"

    first, second = series
    return nil unless first && second

    first_value = latest_value(first)
    second_value = latest_value(second)
    return nil unless first_value && second_value

    initial_year = (first.values.keys & second.values.keys).min
    initial_gap = initial_year ? (first.values[initial_year] - second.values[initial_year]).abs : nil
    current_gap = (first_value - second_value).abs
    closure = initial_gap&.positive? ? ((1 - current_gap / initial_gap) * 100).round : nil
    annotation = specification.fetch("gap_annotation", {})

    {
      y1: y(first_value, layout: layout),
      y2: y(second_value, layout: layout),
      value: current_gap,
      percentage: ((current_gap / [ first_value, second_value ].max) * 100).round,
      label: annotation["mode"] == "closure" ? "#{closure}% smaller" : "#{((current_gap / [ first_value, second_value ].max) * 100).round}% gap",
      sublabel: annotation.fetch("sublabel", "in #{end_year}")
    }
  end

  def dumbbell_ticks
    return specification.fetch("x_ticks").map(&:to_f) if specification["x_ticks"]

    min, max = x_domain
    step = specification.fetch("x_tick_interval", 30).to_f
    (0..((max - min) / step).floor).map { |index| min + index * step }
  end

  def dumbbell_x(value, layout: :desktop)
    plot = dumbbell_plot(layout)
    scale(value, x_domain.first, x_domain.last, plot[:left], plot[:right])
  end

  def dumbbell_y(index, layout: :desktop)
    plot = dumbbell_plot(layout)
    count = [ series.length, 1 ].max
    step = (plot[:bottom] - plot[:top]) / count
    plot[:top] + step * (index + 0.5)
  end

  def series_start(item)
    item.values[start_year] || item.values.values.first
  end

  def series_end(item)
    item.values[end_year] || item.values.values.last
  end

  def series_change(item)
    series_end(item) - series_start(item)
  end

  def scatter_x(value, layout: :desktop)
    plot = scatter_plot(layout)
    scale(value, x_domain.first, x_domain.last, plot[:left], plot[:right])
  end

  def scatter_y(value, layout: :desktop)
    plot = scatter_plot(layout)
    scale(value, y_domain.first, y_domain.last, plot[:bottom], plot[:top])
  end

  def scatter_regression(layout: :desktop)
    return nil if points.length < 2

    mean_x = points.sum(&:x_value) / points.length
    mean_y = points.sum(&:y_value) / points.length
    numerator = points.sum { |point| (point.x_value - mean_x) * (point.y_value - mean_y) }
    denominator = points.sum { |point| (point.x_value - mean_x)**2 }
    return nil if denominator.zero?

    slope = numerator / denominator
    intercept = mean_y - slope * mean_x
    low, high = points.map(&:x_value).minmax

    {
      x1: scatter_x(low, layout: layout),
      y1: scatter_y(intercept + slope * low, layout: layout),
      x2: scatter_x(high, layout: layout),
      y2: scatter_y(intercept + slope * high, layout: layout)
    }
  end

  def scatter_label?(point, layout: :desktop)
    return point.options.fetch("mobile_label", false) if layout == :mobile

    point.options.fetch("direct_label", false)
  end

  def ranked_bar_ticks
    return specification.fetch("x_ticks").map(&:to_f) if specification["x_ticks"]

    min, max = x_domain
    step = specification.fetch("x_tick_interval", 20).to_f
    first = (min / step).ceil * step
    values = []
    current = first
    while current <= max
      values << current
      current += step
    end
    values
  end

  def ranked_bar_x(value, layout: :desktop)
    plot = ranked_bar_plot(layout)
    scale(value, x_domain.first, x_domain.last, plot[:left], plot[:right])
  end

  def ranked_bar_y(index, layout: :desktop)
    plot = ranked_bar_plot(layout)
    count = [ series.length, 1 ].max
    step = (plot[:bottom] - plot[:top]) / count
    plot[:top] + step * (index + 0.5)
  end

  def ranked_bar_height(layout: :desktop)
    plot = ranked_bar_plot(layout)
    count = [ series.length, 1 ].max
    [ (plot[:bottom] - plot[:top]) / count * 0.58, layout == :desktop ? 17.0 : 12.0 ].min
  end

  def ranked_value(item)
    item.values.values.first
  end

  def homepage_series
    keys = specification.fetch("homepage_keys", series.first(6).map(&:key))
    keys.filter_map { |key| series.find { |item| item.key == key } }
  end

  def homepage_ranked_x(value)
    scale(value, x_domain.first, x_domain.last, 138.0, 580.0)
  end

  def homepage_ranked_y(index)
    36.0 + index * 49.0
  end

  def small_panel(index, layout: :desktop)
    if layout == :mobile
      top = 31.0 + index * 181.0
      { left: 40.0, right: 340.0, top: top, bottom: top + 122.0 }
    else
      column = index % 2
      row = index / 2
      left = 62.0 + column * 530.0
      top = 45.0 + row * 295.0
      { left: left, right: left + 455.0, top: top, bottom: top + 210.0 }
    end
  end

  def small_x(index, year, layout: :desktop)
    panel = small_panel(index, layout: layout)
    scale(year, start_year, end_year, panel[:left], panel[:right])
  end

  def small_y(index, value, layout: :desktop)
    panel = small_panel(index, layout: layout)
    scale(value, y_domain.first, y_domain.last, panel[:bottom], panel[:top])
  end

  def small_path_for(item, index, layout: :desktop)
    item.values.sort.map.with_index do |(year, value), point_index|
      command = point_index.zero? ? "M" : "L"
      "#{command} #{small_x(index, year, layout: layout).round(2)} #{small_y(index, value, layout: layout).round(2)}"
    end.join(" ")
  end

  def csv_headers
    case type
    when "scatter"
      [ "country", specification.fetch("x_label"), specification.fetch("y_label") ]
    when "dumbbell"
      [ "country", start_year.to_s, end_year.to_s, "change_percentage_points" ]
    when "ranked_bar"
      [ "country", specification.fetch("measure") ]
    else
      [ "year", *series.map(&:label) ]
    end
  end

  def csv_rows
    case type
    when "scatter"
      points.map { |point| [ point.label, point.x_value, point.y_value ] }
    when "dumbbell"
      series.map { |item| [ item.label, series_start(item), series_end(item), series_change(item) ] }
    when "ranked_bar"
      series.map { |item| [ item.label, ranked_value(item) ] }
    else
      years = series.flat_map { |item| item.values.keys }.uniq.sort
      years.map { |year| [ year, *series.map { |item| item.values[year] } ] }
    end
  end

  def specification
    edition.chart
  end

  private

  def plot_for(layout)
    layout == :mobile ? MOBILE_PLOTS.fetch("line") : PLOT
  end

  def dumbbell_plot(layout)
    return MOBILE_PLOTS.fetch("dumbbell") if layout == :mobile

    { left: 180.0, right: 1_018.0, top: 54.0, bottom: 510.0 }
  end

  def scatter_plot(layout)
    return MOBILE_PLOTS.fetch("scatter") if layout == :mobile

    { left: 80.0, right: 1_022.0, top: 42.0, bottom: 520.0 }
  end

  def ranked_bar_plot(layout)
    if layout == :mobile
      { left: 90.0, right: 318.0, top: 38.0, bottom: mobile_height - 34.0 }
    else
      { left: 176.0, right: 1_012.0, top: 44.0, bottom: desktop_height - 38.0 }
    end
  end

  def scale(value, domain_min, domain_max, range_min, range_max)
    span = domain_max.to_f - domain_min.to_f
    return (range_min + range_max) / 2.0 if span.zero?

    range_min + ((value.to_f - domain_min.to_f) / span) * (range_max - range_min)
  end

  def number_with_delimiter(number)
    number.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
