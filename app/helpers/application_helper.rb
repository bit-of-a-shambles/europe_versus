module ApplicationHelper
  # Format a metric value based on its metadata
  # @param value [Numeric] The value to format
  # @param metadata [Hash] Metadata containing format, unit, decimals info
  # @return [String] Formatted value
  def format_metric_value(value, metadata)
    return '—' if value.nil?
    
    format_type = metadata[:format] || 'integer'
    unit = metadata[:unit] || ''
    decimals = metadata[:decimals] || 0
    
    case format_type
    when 'currency'
      # Format currency values (e.g., $50,000)
      "$#{number_with_delimiter(value.to_i)}"
    when 'decimal'
      # Format decimal values with specified decimal places (e.g., 0.4, 12.5)
      number_with_precision(value, precision: decimals)
    when 'percentage'
      # Format percentage values (e.g., 12.5%)
      "#{number_with_precision(value, precision: decimals)}%"
    when 'integer'
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
    return '—' if value.nil?
    unit_str = unit.to_s.strip
    if unit_str == '%'
      "#{number_with_precision(value, precision: decimals)}%"
    elsif unit_str == 'international_dollars'
      "$#{number_with_delimiter(value.to_i)}"
    else
      # Heuristic: if value has decimals and is small, keep decimals; if large, show delimiter as integer
      if value.is_a?(Numeric) && value % 1 != 0 && value.abs < 1000
        "#{number_with_precision(value, precision: decimals)} #{unit_str}"
      else
        "#{number_with_delimiter(value.to_i)} #{unit_str}"
      end
    end
  end
  
  # Determine if a value should show decimal places based on its magnitude
  # For percentage values < 10, always show decimals
  def should_show_decimals?(value, unit)
    unit&.include?('%') && value < 10
  end
  
  # Get the CSS color class for a growth rate based on metric directionality
  # @param growth_rate [Numeric] The growth rate (can be positive or negative)
  # @param metadata [Hash] Metadata containing higher_is_better info
  # @return [String] CSS class for text color ('text-green-600' or 'text-red-600' or 'text-slate-600')
  def growth_rate_color_class(growth_rate, metadata)
    return 'text-slate-600' if growth_rate.nil? || growth_rate == 0
    
    higher_is_better = metadata[:higher_is_better]
    
    # For neutral metrics (like population), use slate color
    return 'text-slate-600' if higher_is_better.nil?
    
    # For metrics where higher is better (GDP, life expectancy, electricity access)
    # Positive growth = green, negative = red
    if higher_is_better
      growth_rate > 0 ? 'text-green-600' : 'text-red-600'
    else
      # For metrics where lower is better (child mortality, unemployment, CO2 emissions)
      # Negative growth = green (improvement), positive = red (worsening)
      growth_rate > 0 ? 'text-red-600' : 'text-green-600'
    end
  end
end
