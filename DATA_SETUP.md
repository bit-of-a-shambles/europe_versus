# Data Setup Guide

This guide explains how to populate and maintain data in the EuropeVersus application.

## 🚀 Initial Setup (First Time Only)

When deploying the application for the first time, run:

```bash
bin/rails data:initialize
```

### What This Does

This single command will:

1. **Fetch Population Data** (1990-2024)
   - All EU-27 member states
   - Other European countries (UK, Switzerland, Norway, etc.)
   - Eastern Europe & Balkans
   - USA, China, India for comparison

2. **Fetch All Metrics** (via OwidMetricImporter)
   - GDP per capita PPP
   - Child mortality rates
   - Electricity access percentages
   - Health expenditure as % of GDP
   - Life satisfaction scores (Cantril Ladder)
   - Any other metrics configured in `config/owid_metrics.yml`

3. **Calculate European Aggregates**
   - Population-weighted averages for Europe
   - Population-weighted averages for EU-27
   - Proper handling of transcontinental countries

4. **Normalize Units**
   - Ensures consistent units across all metrics
   - `%` for percentages
   - `people` for population
   - `international_dollars` for GDP
   - `% of GDP` for health expenditure
   - `score (0-10)` for life satisfaction

5. **Enrich Descriptions**
   - Adds detailed, human-readable descriptions
   - Explains calculation methodology
   - Notes about population weighting

6. **Verify Data Quality**
   - Checks that all expected records were created
   - Validates Europe and EU-27 aggregates

**Note:** All OWID metrics use the unified `OwidMetricImporter` system. Simply add metrics to `config/owid_metrics.yml` - no need to create separate service classes. See [ADDING_METRICS_GUIDE.md](ADDING_METRICS_GUIDE.md) for details.

### Expected Output

```
🚀 Starting initial data population...
============================================================
This will take approximately 3-4 minutes.
============================================================

📊 Step 1/6: Fetching population data...
   ✅ Population data loaded

� Step 2/6: Fetching OWID metrics...
   ✅ All OWID metrics loaded

🧮 Step 3/6: Calculating European aggregates...

✅ INITIALIZATION COMPLETE!
============================================================
⏱️  Time taken: 212.45 seconds

📊 Data Summary:
   • Population records: 1,089
   • GDP records: 3,204
   • Child mortality records: 458
   • Electricity access records: 612
   • Health expenditure records: 828
   • Life satisfaction records: 467
   • Total metrics: 6,658
   • Countries covered: 52

🎉 Your application is ready to use!
```

---

## 🔄 Adding New Statistics

### Automatic Method (Production - Recommended)

**Just edit config/owid_metrics.yml and deploy!**

1. Edit `config/owid_metrics.yml` and add your metric
2. Commit and push to your repo
3. Deploy

The app will automatically detect and import the new metric on startup. No manual commands needed!

See [ADDING_METRICS_GUIDE.md](ADDING_METRICS_GUIDE.md) for detailed instructions.

### Manual Method (Development)

For OWID metrics, edit `config/owid_metrics.yml` first, then:

```bash
bin/rails owid:import_all
```

For custom data sources or refreshing all data:

```bash
bin/rails data:update
```

### What This Does

1. **Refreshes All Data Sources**
   - Re-fetches population data
   - Re-fetches all OWID metrics from config
   - Adds any new metrics you've configured

2. **Recalculates All Aggregates**
   - Europe aggregates for all metrics
   - EU-27 aggregates for all metrics
   - Uses latest population data for weighting

3. **Normalizes & Enriches**
   - Normalizes units for new data
   - Enriches descriptions for new aggregates

### When to Run This

- After adding a new metric to the application
- To refresh data with latest values from Our World in Data
- After fixing data issues or calculation bugs
- Periodically (e.g., monthly) to keep data current

### Example Workflow

```bash
# 1. Edit config/owid_metrics.yml to add your metric
# 2. Run import to fetch the new data
bin/rails owid:import_all

# 3. Verify the new data
bin/rails console
> Metric.where(metric_name: 'your_metric_name').count
```

---

## 🔍 Verification Commands

After running initialization or updates, verify your data:

### Check Overall Stats
```bash
# Population statistics
bin/rails data:population_stats

# GDP latest values
bin/rails gdp_data:show_latest

# Health expenditure latest values
bin/rails health_social_data:show_health_expenditure

# Life satisfaction latest values
bin/rails health_social_data:show_life_satisfaction

# Europe population summary
bin/rails data:europe_population_summary

# Verify Czechia data specifically
bin/rails data:verify_czechia
```

### Check Database Directly
```bash
# Rails console
bin/rails console

# Count metrics by type
Metric.group(:metric_name).count

# Check Europe aggregates
Metric.where(country: 'europe').pluck(:metric_name, :year, :metric_value)

# Latest data for a country
Metric.latest_for_country_and_metric('germany', 'gdp_per_capita_ppp')
```

---

## 📋 Individual Tasks (Advanced)

If you need to run specific tasks individually:

### Data Fetching
```bash
# Population only
bin/rails data:fetch_population

# All OWID metrics (from config/owid_metrics.yml)
bin/rails owid:import_all

# All data sources
bin/rails data:fetch_all
```

### Calculations
```bash
# Calculate Europe population
bin/rails data:calculate_europe_population

# Calculate Europe GDP
bin/rails gdp_data:calculate_europe
```

### Data Quality
```bash
# Normalize units
bin/rails data:normalize_units

# Enrich descriptions
bin/rails data:enrich_aggregate_descriptions
```

### Cleanup
```bash
# Clear all data for a specific metric
bin/rails console
> Metric.where(metric_name: 'gdp_per_capita_ppp').delete_all
```

---

## 🛠️ Service Architecture

The application uses a simplified, modular architecture:

### Core Services (4 Total)

1. **`OwidMetricImporter`** - Universal OWID metric handler
   - Reads configuration from `config/owid_metrics.yml`
   - Fetches data from Our World in Data
   - Stores data in database
   - Calculates aggregates
   - **Use this for ALL OWID metrics** - no need to create new services

2. **`PopulationDataService`** - Population data handler
   - Fetches population data from OWID
   - Used by other services for weighted calculations
   - Handles European aggregate calculations

3. **`EuropeanMetricsService`** - Aggregation engine
   - Calculates Europe and EU-27 aggregates
   - Population-weighted averages
   - Simple sums for absolute metrics
   - Used by all other services

4. **`OurWorldInDataService`** - Low-level API wrapper
   - CSV data fetching from OWID
   - JSON metadata parsing
   - Used by OwidMetricImporter and PopulationDataService

### Legacy Services (Being Phased Out)

The following services are **deprecated** and should not be used for new metrics:
- `DevelopmentDataService` → Use `OwidMetricImporter` instead
- `EnergyDataService` → Use `OwidMetricImporter` instead
- `HealthSocialDataService` → Use `OwidMetricImporter` instead
- `GdpDataService` → Use `OwidMetricImporter` instead

These exist only for backward compatibility with old rake tasks.

### Adding New Metrics

**DO NOT** create new service classes. Instead:

1. Edit `config/owid_metrics.yml`
2. Add your metric configuration
3. Commit and deploy (auto-imports on startup)

See [ADDING_METRICS_GUIDE.md](ADDING_METRICS_GUIDE.md) for detailed instructions.

---

## 🛠️ Adding a Custom Metric (Non-OWID)

If you need to add a metric from a source OTHER than Our World in Data:

### Step 1: Create a Dedicated Service (Only if Not OWID)

Example for a new metric called "life_expectancy":

```ruby
# app/services/health_data_service.rb
class HealthDataService
  def self.fetch_and_store_life_expectancy
    result = OurWorldInDataService.fetch_chart_data(
      'life-expectancy',
      start_year: 2000,
      end_year: 2024
    )
    
    return result if result[:error]
    
    store_metric_data(result, 'life_expectancy')
    calculate_aggregates('life_expectancy')
    result
  end
  
  private
  
  def self.store_metric_data(result, metric_name)
    # Store individual country data
    result[:countries].each do |country_key, country_data|
      country_data[:data].each do |year, value|
        Metric.find_or_create_by!(
          country: country_key,
          metric_name: metric_name,
          year: year
        ).update!(
          metric_value: value,
          unit: result.dig(:metadata, :unit) || 'years',
          source: result.dig(:metadata, :source) || 'Our World in Data',
          description: result.dig(:metadata, :description)
        )
      end
    end
  end
  
  def self.calculate_aggregates(metric_name)
    # Calculate Europe aggregate
    EuropeanMetricsService.calculate_europe_aggregate(metric_name)
    
    # Calculate EU-27 aggregate
    EuropeanMetricsService.calculate_group_aggregate(
      metric_name,
      country_keys: EuropeanMetricsService::EU27_COUNTRIES,
      target_key: 'european_union'
    )
  end
end
```

### Step 2: Add Rake Task (Optional)

```ruby
# lib/tasks/health_data.rake
namespace :health_data do
  desc "Fetch and store life expectancy data"
  task fetch_life_expectancy: :environment do
    puts "Fetching life expectancy data..."
    result = HealthDataService.fetch_and_store_life_expectancy
    
    if result[:error]
      puts "Error: #{result[:error]}"
    else
      puts "✅ Successfully stored life expectancy data"
      puts "   Records: #{Metric.for_metric('life_expectancy').count}"
    end
  end
end
```

### Step 3: Update Metadata Configuration

Add metadata to `EuropeanMetricsService.get_metric_metadata`:

```ruby
when 'life_expectancy'
  {
    unit: 'years',
    format: 'decimal',
    decimals: 1,
    aggregation_method: :population_weighted
  }
```

### Step 4: Update Enrich Descriptions Task

Add description template to `lib/tasks/enrich_descriptions.rake`:

```ruby
when 'life_expectancy'
  "Population-weighted #{country_label} life expectancy at birth, using country populations as weights; adjusted for transcontinental populations."
```

### Step 5: Update Normalize Units Task

Add unit mapping to `lib/tasks/normalize_units.rake`:

```ruby
mapping = {
  # ... existing mappings ...
  'life_expectancy' => 'years'
}
```

### Step 6: Run Update

```bash
# Fetch new data and calculate aggregates
bin/rails data:update

# Verify
bin/rails console
> Metric.where(metric_name: 'life_expectancy').count
> Metric.latest_for_country_and_metric('europe', 'life_expectancy')
```

---

## 📊 Data Sources

All data is sourced from reputable international organizations:

- **All OWID Metrics**: Our World in Data (various sources)
  - Population: UN estimates
  - GDP: World Bank
  - Child Mortality: UN IGME
  - Electricity Access: World Bank
  - Health Expenditure: World Bank / WHO
  - Life Satisfaction: Wellbeing Research Centre (Cantril Ladder)
  - And any other metrics configured in `config/owid_metrics.yml`

**Note**: The `OwidMetricImporter` handles all Our World in Data metrics. You don't need to know the specific source - just configure the metric in the YAML file.

### Required Files

The application automatically fetches most data from APIs. No CSV files required unless using legacy GDP import:

- ~~`public/gdp-per-capita-worldbank.csv`~~ - No longer needed (GDP now imported via OwidMetricImporter)

---

## ⚠️ Troubleshooting

### Task appears stuck or frozen

**Population fetch specifically:**
- The population data fetch requests data for 52 countries from Our World in Data
- This can take 30-60 seconds and may appear frozen
- Look for the message: "Requesting data for 52 countries..."
- The task has a 120-second timeout - if it truly hangs, it will fail after 2 minutes
- If it times out repeatedly:
  ```bash
  # Try fetching fewer countries or check OWID API status
  # Visit https://ourworldindata.org/grapher/population to verify the API is working
  ```

### "Population data fetch failed"
- Check network connectivity to ourworldindata.org
- Verify the OWID API is accessible
- Check Rails logs for specific error messages

### "GDP fetch failed"
- GDP is now imported via `OwidMetricImporter`
- Check that `gdp_per_capita_ppp` is enabled in `config/owid_metrics.yml`
- Run `bin/rails owid:import_all` to fetch

### "Europe aggregate calculation failed"
- Ensure population data exists first
- Check that country data is available for the metric
- Verify at least a few EU countries have data

### Task hangs or times out
- Check network connectivity
- OWID API may be slow or temporarily down
- Try running individual tasks to isolate the issue

### Data looks incorrect
```bash
# Clear and re-fetch specific metric using OwidMetricImporter
bin/rails console
> Metric.where(metric_name: 'gdp_per_capita_ppp').delete_all
> OwidMetricImporter.import_metric('gdp_per_capita_ppp')
```

---

## 🔐 Production Considerations

### Environment Variables

Ensure these are set in production:

```bash
RAILS_ENV=production
DATABASE_URL=your_database_url
```

### Running in Production

```bash
# Initial setup on fresh deploy
RAILS_ENV=production bin/rails data:initialize

# Regular updates (e.g., via cron job)
RAILS_ENV=production bin/rails data:update
```

### Automated Updates (Optional)

Add to crontab for monthly updates:

```cron
# Run data update on the 1st of each month at 2 AM
0 2 1 * * cd /path/to/app && RAILS_ENV=production bin/rails data:update >> log/data_update.log 2>&1
```

---

## 📝 Summary

| Command | When to Use |
|---------|-------------|
| `bin/rails data:initialize` | First deployment only |
| `bin/rails data:update` | After adding new statistics or monthly |
| `bin/rails data:fetch_all` | Manual refresh of all data sources |
| Individual tasks | Debugging or targeted updates |

**Need help?** Check the Rails logs in `log/production.log` or run tasks with `--trace` for detailed error information.
