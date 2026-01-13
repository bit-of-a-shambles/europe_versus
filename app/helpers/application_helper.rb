module ApplicationHelper
  # Format a metric value based on its metadata
  # @param value [Numeric] The value to format
  # @param metadata [Hash] Metadata containing format, unit, decimals info
  # @return [String] Formatted value
  def format_metric_value(value, metadata)
    return "\u2014" if value.nil?

    format_type = metadata[:format] || "integer"
    unit = metadata[:unit] || ""
    decimals = metadata[:decimals] || 0

    case format_type
    when "currency"
      # Format currency values (e.g., $50,000)
      "$#{number_with_delimiter(value.to_i)}"
    when "decimal"
      # Format decimal values with specified decimal places (e.g., 0.4, 12.5)
      number_with_precision(value, precision: decimals)
    when "percentage"
      # Format percentage values (e.g., 12.5%)
      "#{number_with_precision(value, precision: decimals)}%"
    when "integer"
      # Format integer values with delimiters (e.g., 1,234,567)
      number_with_delimiter(value.to_i)
    else
      # Default to string representation
      value.to_s
    end
  end

  # Format a value with its unit for inline displays (e.g., in cards and comparisons)
  # Defaults to two decimals for percentage metrics
  def format_value_with_unit(value, unit, decimals: 2)
    return "\u2014" if value.nil?
    unit_str = unit.to_s.strip.downcase

    # Handle percentage units
    if unit_str == "%" || unit_str.include?("percent")
      return "#{number_with_precision(value, precision: decimals)}%"
    end

    # Handle currency/dollar units - show as $X,XXX for large values, $X.XX for small
    if unit_str.include?("$") || unit_str.include?("dollar") || unit_str.include?("international") || unit_str.include?("usd") || unit_str.include?("ppp")
      if value.abs < 1000
        return "$#{number_with_precision(value, precision: decimals)}"
      else
        return "$#{number_with_delimiter(value.round(0))}"
      end
    end

    # Handle score-based units (e.g., "score (0-10)")
    if unit_str.include?("score")
      return number_with_precision(value, precision: decimals)
    end

    # Handle rate units (per 100, per 1000, per million, etc.)
    if unit_str.include?("per 100") || unit_str.include?("per 1,000") || unit_str.include?("per million")
      return number_with_precision(value, precision: decimals)
    end

    # Handle years
    if unit_str == "years"
      return "#{number_with_precision(value, precision: 1)} years"
    end

    # Handle people/population - use compact format for large numbers
    if unit_str == "people" || unit_str.include?("population")
      return format_compact_number(value)
    end

    # Handle births per woman
    if unit_str.include?("births")
      return number_with_precision(value, precision: 2)
    end

    # Default: format based on value magnitude
    if value.is_a?(Numeric)
      if value.abs < 100
        number_with_precision(value, precision: decimals)
      else
        number_with_delimiter(value.round(0))
      end
    else
      value.to_s
    end
  end

  # Determine if a value should show decimal places based on its magnitude
  # For percentage values < 10, always show decimals
  def should_show_decimals?(value, unit)
    unit&.include?("%") && value < 10
  end

  # Format large numbers in compact form (e.g., 1.4B, 450M, 83.5M)
  def format_compact_number(value)
    return "—" if value.nil?

    if value >= 1_000_000_000
      # Billions
      formatted = value / 1_000_000_000.0
      if formatted == formatted.round
        "#{formatted.round}B"
      else
        "#{number_with_precision(formatted, precision: 1, strip_insignificant_zeros: true)}B"
      end
    elsif value >= 1_000_000
      # Millions
      formatted = value / 1_000_000.0
      if formatted >= 100
        "#{formatted.round}M"
      elsif formatted == formatted.round
        "#{formatted.round}M"
      else
        "#{number_with_precision(formatted, precision: 1, strip_insignificant_zeros: true)}M"
      end
    elsif value >= 1_000
      # Thousands
      formatted = value / 1_000.0
      "#{number_with_precision(formatted, precision: 1, strip_insignificant_zeros: true)}K"
    else
      number_with_delimiter(value.round(0))
    end
  end

  # Get the CSS color class for a growth rate based on metric directionality
  # @param growth_rate [Numeric] The growth rate (can be positive or negative)
  # @param metadata [Hash] Metadata containing higher_is_better info
  # @return [String] CSS class for text color ('text-green-600' or 'text-red-600' or 'text-slate-600')
  def growth_rate_color_class(growth_rate, metadata)
    return "text-slate-600" if growth_rate.nil? || growth_rate == 0

    higher_is_better = metadata[:higher_is_better]

    # For neutral metrics (like population), use slate color
    return "text-slate-600" if higher_is_better.nil?

    # For metrics where higher is better (GDP, life expectancy, electricity access)
    # Positive growth = green, negative = red
    if higher_is_better
      growth_rate > 0 ? "text-green-600" : "text-red-600"
    else
      # For metrics where lower is better (child mortality, unemployment, CO2 emissions)
      # Negative growth = green (improvement), positive = red (worsening)
      growth_rate > 0 ? "text-red-600" : "text-green-600"
    end
  end
end
