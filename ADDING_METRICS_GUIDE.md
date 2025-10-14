# Adding New Metrics - The Zero-Terminal Way

**You don't need to run anything!** Just edit a YAML file, commit, and deploy. The app automatically imports new metrics on startup.

**Important:** The `OwidMetricImporter` handles **ALL** Our World in Data metrics. You never need to create new service classes - just edit the YAML configuration.

## 🎯 The Simplest Method (Recommended)

### Step 1: Find the OWID Slug

Visit [Our World in Data](https://ourworldindata.org/charts) and find your metric.

Example URL: `https://ourworldindata.org/grapher/renewable-energy-consumption`  
**Slug:** `renewable-energy-consumption`

### Step 2: Edit config/owid_metrics.yml

Add your metric to the YAML file:

```yaml
renewable_energy:
  owid_slug: renewable-energy-consumption
  start_year: 1990
  end_year: 2024
  unit: "terawatt-hours"
  description: "Renewable energy consumption"
  category: environment  # Where it appears: economy, social, development, health, environment, innovation
  aggregation_method: population_weighted
  enabled: true
```

**Available Categories:**
- `economy` - GDP, income, employment, trade
- `social` - Population, demographics, quality of life
- `development` - Infrastructure, education, basic services
- `health` - Healthcare, disease, mortality
- `environment` - Climate, emissions, energy, resources
- `innovation` - R&D, technology, patents

### Step 3: Commit and Deploy

```bash
git add config/owid_metrics.yml
git commit -m "Add renewable energy metric"
git push
```

**That's it!** The app will:
- ✅ Detect the new metric on startup
- ✅ Automatically fetch data from OWID
- ✅ Calculate Europe & EU-27 aggregates
- ✅ Store everything in the database
- ✅ Display in the correct category section

**No terminal commands. No service classes. No manual imports.** Just YAML → Git → Deploy.

---

## 🏗️ Service Architecture (For Understanding)

The application uses a **unified approach** for all OWID metrics:

### Active Services (4 Total)

1. **`OwidMetricImporter`** ⭐ 
   - Handles **ALL** Our World in Data metrics
   - Configured via `config/owid_metrics.yml`
   - No need to create new services!

2. **`PopulationDataService`**
   - Fetches population data
   - Used for weighted calculations

3. **`EuropeanMetricsService`**
   - Calculates aggregates
   - Population-weighted averages

4. **`OurWorldInDataService`**
   - Low-level API wrapper
   - Used by OwidMetricImporter

### ⚠️ Legacy Services (DO NOT USE for new metrics)

These services still exist but are **deprecated**:
- ~~`DevelopmentDataService`~~ → Use `OwidMetricImporter`
- ~~`EnergyDataService`~~ → Use `OwidMetricImporter`
- ~~`HealthSocialDataService`~~ → Use `OwidMetricImporter`
- ~~`GdpDataService`~~ → Use `OwidMetricImporter`

They exist only for backward compatibility. **All new metrics should use the YAML config approach.**

---

## 🔧 Configuration Options

In `config/owid_metrics.yml`:

**Required Fields:**
- `owid_slug` - The slug from the OWID URL
- `start_year` - First year to import (e.g., 1990)
- `end_year` - Last year to import (e.g., 2024)
- `unit` - Unit of measurement (e.g., "%", "score (0-10)", "kg")
- `description` - Human-readable description
- `category` - Section where metric appears (economy, social, development, health, environment, innovation)
- `aggregation_method` - How to calculate Europe aggregate

**Categories** (determines where metric shows in statistics page):
- `economy` - GDP, income, employment, trade
- `social` - Population, demographics, quality of life  
- `development` - Infrastructure, education, basic services
- `health` - Healthcare, disease, mortality
- `environment` - Climate, emissions, energy, resources
- `innovation` - R&D, technology, patents

**Aggregation Methods:**
- `population_weighted` - Weighted by population (most common)
- `sum` - Simple sum across countries
- `average` - Simple average

**Optional Fields:**
- `enabled` - Set to `false` to temporarily disable (default: `true`)

---

## 🚀 Local Development

In development, auto-import is disabled by default to speed up startup.

To enable auto-import locally:
```bash
OWID_AUTO_IMPORT=1 bin/rails server
```

Or manually import after editing the YAML:
```bash
bin/rails owid:import_all
```

---

## 📋 Manual Terminal Commands (Optional)

If you prefer terminal commands, these still work:

```bash
# Quick one-liner to test a metric
bin/rails 'owid:quick[renewable-energy-consumption]'

# Import specific metric
bin/rails "owid:import[metric_name]"

# Import all configured metrics
bin/rails owid:import_all

# List all metrics
bin/rails owid:list

# Show stats for a metric
bin/rails "owid:stats[metric_name]"
```

---

## 📊 Current Metrics

Run `bin/rails owid:list` or check `config/owid_metrics.yml` to see all configured metrics.

---

## 💡 Example: Adding CO2 Emissions

**1. Find the slug:**  
Visit https://ourworldindata.org/grapher/co2-emissions-per-capita  
Slug: `co2-emissions-per-capita`

**2. Edit config/owid_metrics.yml:**
```yaml
co2_emissions:
  owid_slug: co2-emissions-per-capita
  start_year: 1990
  end_year: 2024
  unit: "tonnes per capita"
  description: "CO2 emissions per capita"
  category: environment
  aggregation_method: population_weighted
  enabled: true
```

**3. Commit and push:**
```bash
git add config/owid_metrics.yml
git commit -m "Add CO2 emissions per capita metric"
git push
```

**4. Deploy completes** → Data automatically imported ✅

---

## 🔄 Updating Existing Metrics

To update a metric (e.g., extend year range):

1. Edit the metric in `config/owid_metrics.yml`
2. Commit and push
3. On next deploy, run: `bin/rails owid:import_all`

The importer will update existing records and add new ones.

---

## 🚫 Temporarily Disabling Metrics

Set `enabled: false` to disable without deleting:

```yaml
old_metric:
  enabled: false  # Will be skipped
  owid_slug: some-old-metric
  # ... rest of config
```

---

## 🆘 Troubleshooting

**Metric not importing?**
- Check the OWID slug is correct
- Verify the metric exists at https://ourworldindata.org/grapher/YOUR-SLUG
- Check logs for error messages

**Want to test locally first?**
```bash
OWID_AUTO_IMPORT=1 bin/rails server
# Or manually: bin/rails "owid:import[your_metric]"
```

**Need to reimport?**
```bash
# Delete old data
rails console
Metric.where(metric_name: 'your_metric').delete_all

# Reimport
bin/rails "owid:import[your_metric]"
```
