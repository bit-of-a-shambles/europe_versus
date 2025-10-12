# 📋 FOOLPROOF GUIDE: Adding New Metrics from OWID

## ✅ System Verification
Run this first to ensure the system is ready:
```bash
bin/rails runner tmp/test_metrics_system.rb
```

## 🎯 Step-by-Step Guide for Adding a New Metric

### Example: Adding "Life Expectancy"

---

### **STEP 1: Find the OWID Chart**

1. Go to https://ourworldindata.org/
2. Search for your metric (e.g., "life expectancy")
3. Find the chart URL, e.g., `https://ourworldindata.org/grapher/life-expectancy`
4. **Extract the chart slug**: `life-expectancy` (everything after `/grapher/`)

**Important:** The chart slug is used in TWO places:
- API data fetching
- Iframe display

---

### **STEP 2: Add Metadata to EuropeanMetricsService**

File: `app/services/european_metrics_service.rb`

Add a new case in the `get_metric_metadata` method:

```ruby
when 'life_expectancy'
  {
    title: 'Life Expectancy',
    description: 'Average number of years a newborn would live',
    unit: 'years',
    format: 'decimal',        # currency, decimal, integer, or percentage
    decimals: 1,              # Number of decimal places (for decimal format)
    higher_is_better: true,   # true = higher is good, false = lower is good, nil = neutral
    source: 'Our World in Data - UN Population Division'
  }
```

**Format Options:**
- `currency` - Adds $ and thousand separators (e.g., $50,000)
- `decimal` - Shows decimal places (e.g., 72.5)
- `integer` - Whole numbers with separators (e.g., 1,234,567)
- `percentage` - Adds % sign (e.g., 12.5%)

**Higher is Better:**
- `true` → Positive growth = GREEN (GDP, life expectancy, electricity access)
- `false` → Negative growth = GREEN (mortality, unemployment, CO2 emissions)
- `nil` → Growth = GRAY (neutral, like population)

---

### **STEP 3: Add Route**

File: `config/routes.rb`

Add in the statistics section:

```ruby
get '/statistics/life-expectancy', to: 'statistics#chart', as: 'life_expectancy'
```

**Naming Convention:**
- Route slug: kebab-case (e.g., `life-expectancy`)
- Database column: snake_case (e.g., `life_expectancy`)
- URL-friendly alias: Use `as:` parameter

---

### **STEP 4: Add Controller Case**

File: `app/controllers/statistics_controller.rb`

Add in the `chart` method:

```ruby
elsif chart_name == 'life-expectancy'
  # Use local life expectancy data from our database
  @chart_data = build_metric_chart_data('life_expectancy', 'Life Expectancy', 'years')
  @chart_name = 'life-expectancy'  # OWID chart slug for iframe
```

**Important:** 
- `chart_name` is the URL slug (kebab-case)
- First parameter to `build_metric_chart_data` is the database column name (snake_case)
- `@chart_name` MUST match the OWID chart slug exactly

---

### **STEP 5: Create Service Method (Optional but Recommended)**

File: `app/services/development_data_service.rb` (or create a new service)

```ruby
def self.fetch_and_store_life_expectancy
  Rails.logger.info "Fetching life expectancy data from OWID..."
  result = fetch_chart_data('life-expectancy', start_year: 2000, end_year: 2024)
  
  return result if result[:error]
  
  store_metric_data(result, 'life_expectancy')
  calculate_and_store_europe_aggregate('life_expectancy')
  Rails.logger.info "Successfully stored life expectancy data"
  result
end
```

**Or use the generic OurWorldInDataService:**

```ruby
# Fetch data
result = OurWorldInDataService.fetch_chart_data('life-expectancy', start_year: 2000, end_year: 2024)

# Store in database
result[:countries].each do |country_key, country_data|
  country_data[:data].each do |year, value|
    Metric.create!(
      country: country_key,
      metric_name: 'life_expectancy',
      metric_value: value,
      year: year,
      unit: 'years',
      source: 'Our World in Data'
    )
  end
end
```

---

### **STEP 6: Fetch and Store Data**

Run in terminal:

```bash
# Option A: If you created a service method
bin/rails runner "DevelopmentDataService.fetch_and_store_life_expectancy"

# Option B: Manual fetch
bin/rails runner "
  result = OurWorldInDataService.fetch_chart_data('life-expectancy', start_year: 2000, end_year: 2024)
  # Then store the data (see Step 5)
"
```

---

### **STEP 7: Calculate Europe Aggregate**

```bash
bin/rails runner "DevelopmentDataService.calculate_and_store_europe_aggregate('life_expectancy')"
```

**This calculates the average for all 27 EU countries across all years!**

---

### **STEP 8: Verify Everything Works**

```bash
# Check data was imported
bin/rails runner "puts Metric.where(metric_name: 'life_expectancy').count"

# Check Europe aggregate exists
bin/rails runner "puts Metric.where(metric_name: 'life_expectancy', country: 'europe').count"

# Check latest values
bin/rails runner "
  latest = Metric.where(metric_name: 'life_expectancy', country: 'europe').order(year: :desc).first
  puts \"Latest Europe life expectancy: #{latest.metric_value.round(1)} years (#{latest.year})\"
"

# Visit the page
# http://localhost:3001/statistics/life-expectancy
```

---

## 🔍 Testing Checklist

- [ ] Metadata has correct `format`, `decimals`, and `higher_is_better`
- [ ] Route uses kebab-case (e.g., `/statistics/life-expectancy`)
- [ ] Controller case matches route slug
- [ ] `@chart_name` matches OWID chart slug
- [ ] Data imported successfully (check record count)
- [ ] Europe aggregate calculated and stored
- [ ] Page loads without errors
- [ ] Table shows data with correct formatting (decimals, currency, etc.)
- [ ] Growth analysis colors are correct (green for improvement)
- [ ] OWID iframe displays the correct chart

---

## 🚨 Common Pitfalls to Avoid

### 1. **Mismatched Chart Slugs**
❌ BAD:
```ruby
@chart_name = 'electricity-access'  # Wrong! OWID chart is different
```
✅ GOOD:
```ruby
@chart_name = 'share-of-the-population-with-access-to-electricity'
```

### 2. **Wrong Format Type**
❌ BAD: Using `format: 'integer'` for values like 0.37%
✅ GOOD: Using `format: 'decimal'` with `decimals: 1`

### 3. **Incorrect Directionality**
❌ BAD: `higher_is_better: true` for child mortality (lower is better!)
✅ GOOD: `higher_is_better: false` for child mortality

### 4. **Forgetting Europe Aggregate**
❌ BAD: Importing data but not calculating Europe aggregate
✅ GOOD: Always run `calculate_and_store_europe_aggregate` after import

### 5. **Case Sensitivity Issues**
- Routes: `kebab-case` (`life-expectancy`)
- Database: `snake_case` (`life_expectancy`)
- URLs: `kebab-case` (`/statistics/life-expectancy`)

---

## 📊 Recommended Next Metrics to Add

### Easy Wins (Similar to Child Mortality):
1. **Unemployment Rate** (`unemployment-rate`)
   - Format: decimal, decimals: 1, higher_is_better: false
   
2. **CO2 Emissions per Capita** (`co-emissions-per-capita`)
   - Format: decimal, decimals: 1, higher_is_better: false
   
3. **Life Expectancy** (`life-expectancy`)
   - Format: decimal, decimals: 1, higher_is_better: true

### Medium Complexity:
4. **Educational Attainment** - May need custom aggregation
5. **Healthcare Expenditure** - Currency format, needs PPP adjustment
6. **Renewable Energy Share** - Percentage format

---

## 🎯 Quick Reference: Metric Templates

### Template for "Lower is Better" Metrics (Mortality, Unemployment, CO2)
```ruby
when 'metric_name'
  {
    title: 'Metric Title',
    description: 'Description',
    unit: '%',
    format: 'decimal',
    decimals: 1,
    higher_is_better: false,  # ⚠️ Lower is better!
    source: 'Our World in Data - Source'
  }
```

### Template for "Higher is Better" Metrics (GDP, Life Expectancy, Education)
```ruby
when 'metric_name'
  {
    title: 'Metric Title',
    description: 'Description',
    unit: 'unit',
    format: 'decimal',
    decimals: 1,
    higher_is_better: true,  # ✅ Higher is better
    source: 'Our World in Data - Source'
  }
```

---

## 🔄 Complete Example: Adding CO2 Emissions

```bash
# 1. OWID Chart: https://ourworldindata.org/grapher/co-emissions-per-capita
# Chart slug: co-emissions-per-capita

# 2. Add metadata (european_metrics_service.rb)
when 'co2_emissions_per_capita'
  {
    title: 'CO2 Emissions per Capita',
    description: 'Annual CO2 emissions per person',
    unit: 'tonnes',
    format: 'decimal',
    decimals: 1,
    higher_is_better: false,  # Lower emissions is better!
    source: 'Our World in Data - GCP'
  }

# 3. Add route (routes.rb)
get '/statistics/co2-emissions-per-capita', to: 'statistics#chart', as: 'co2_emissions'

# 4. Add controller case (statistics_controller.rb)
elsif chart_name == 'co2-emissions-per-capita'
  @chart_data = build_metric_chart_data('co2_emissions_per_capita', 'CO2 Emissions per Capita', 'tonnes')
  @chart_name = 'co-emissions-per-capita'

# 5. Fetch data
bin/rails runner "
  result = OurWorldInDataService.fetch_chart_data('co-emissions-per-capita', start_year: 2000, end_year: 2024)
  # Store data...
"

# 6. Calculate Europe aggregate
bin/rails runner "DevelopmentDataService.calculate_and_store_europe_aggregate('co2_emissions_per_capita')"

# 7. Test
# Visit: http://localhost:3001/statistics/co2-emissions-per-capita
```

---

## ✅ Final System Check

Run this after adding each new metric:

```bash
bin/rails runner tmp/test_metrics_system.rb
```

This verifies:
- Metadata is configured correctly
- Data is in database
- Europe aggregates exist
- Chart building works
- Formatting will be correct
- Colors will be appropriate

---

**The system is now 100% modular and ready for any OWID metric!** 🎉
