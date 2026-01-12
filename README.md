# EuropeVersus 🇪🇺

![Tests](https://img.shields.io/badge/tests-256%20passing-brightgreen)
![Test Coverage](https://img.shields.io/badge/coverage-79.47%25-brightgreen)

An **open source** Rails 8 web application that provides evidence-based comparisons between European statistics and those of the United States, India, and China. This project aims to counter negative narratives about Europe by presenting factual data in an accessible, visual format.

## Mission

EuropeVersus promotes data-driven understanding of European performance across multiple dimensions. Too often, discussions about Europe focus on challenges without acknowledging the continent's remarkable achievements in quality of life, social progress, and sustainable development.

**This is an open source, community-driven project.** We believe that accurate data should be freely accessible and continuously improved by contributors worldwide.

## Features

- **Comprehensive Statistics**: Compare Europe with the US, India, and China across economics, social indicators, environment, and innovation
- **Multiple European Groupings**: Compare Europe, EU-27, Core EU (founding members), Eurozone, Non-Euro EU, and Non-EU Europe
- **Fact Check Articles**: In-depth, markdown-based articles examining common claims about Europe with embedded live data
- **Beautiful Visualizations**: Clean, responsive design with interactive comparison charts
- **Social Sharing**: OG images and share buttons optimized for social media
- **Mobile-First**: Optimized for all devices with Tailwind CSS
- **Fast & Modern**: Built with Rails 8, Turbo, SQLite, and minimal JavaScript
- **Evidence-Based**: All data sourced from official statistics and reputable international organizations

## Tech Stack

- **Backend**: Ruby on Rails 8
- **Frontend**: Tailwind CSS, Turbo, Stimulus
- **Database**: SQLite
- **Content**: Markdown with YAML frontmatter for fact-check articles
- **Image Generation**: Grover (Puppeteer) for OG images
- **Deployment**: Docker-ready with Kamal configuration

## European Groupings

The application calculates aggregates for multiple European groupings:

| Grouping | Description | Countries |
|----------|-------------|-----------|
| **Europe** | All European countries | ~50 countries including transcontinental |
| **EU-27** | European Union members | 27 member states |
| **Core EU** | Founding EEC members | Germany, France, Italy, Netherlands, Belgium, Luxembourg |
| **Eurozone** | Euro currency users | 20 countries |
| **Non-Euro EU** | EU members without Euro | Poland, Sweden, Denmark, Czechia, Hungary, Romania, Bulgaria |
| **Non-EU Europe** | European non-EU states | UK, Switzerland, Norway, Iceland |

All aggregates are population-weighted averages adjusted for transcontinental populations.


## Data Categories

The application includes statistics across multiple categories, with data sourced from Our World in Data (OWID), the International Labour Organization (ILO), and other reputable sources:

### Economy
- GDP per Capita (PPP)
- Labor Productivity per Hour (ILO)
- Labor Productivity per Worker (ILO)
- Median Income Daily
- Poorest 10% Income

### Social
- Population
- Life Satisfaction
- Fertility Rate
- State Capacity Index
- Functioning Government Index
- Homicide Rate

### Development
- Child Mortality Rate
- Access to Electricity
- Public Transport Access
- PISA Math Performance
- PISA Reading Performance

### Environment
- Low Carbon Energy Share

### Innovation
- Researchers per Million
- Research Spending (% of GDP)
- Scientific Journal Articles

### Health
- Health Expenditure (% of GDP)
- Healthy Life Expectancy
- Medical RCTs Published

## Metrics Configuration System

The application uses a unified YAML configuration file (`config/metrics.yml`) that supports multiple data sources.

### Supported Data Sources

1. **OWID (Our World in Data)**: The primary source for most metrics
2. **ILO (International Labour Organization)**: Labor productivity metrics

### Adding New Metrics

**Zero-terminal workflow!** Just edit the YAML file and deploy.

1. **Add to `config/metrics.yml`:**

   For OWID metrics:
   ```yaml
   renewable_energy:
     source: owid
     owid_slug: renewable-energy-consumption
     start_year: 1990
     end_year: 2024
     unit: "terawatt-hours"
     description: "Renewable energy consumption"
     category: environment
     aggregation_method: population_weighted
     enabled: true
   ```

   For ILO metrics:
   ```yaml
   labor_productivity_per_hour_ilo:
     source: ilo
     ilo_indicator: labor_productivity_per_hour
     start_year: 2000
     end_year: 2025
     unit: "2021 PPP $ per hour"
     description: "Output per hour worked"
     category: economy
     aggregation_method: population_weighted
     enabled: true
   ```

2. **Commit and push:**
   ```bash
   git add config/metrics.yml
   git commit -m "Add renewable energy metric"
   git push
   ```

3. **Deploy** → The app automatically imports new metrics on startup!

**How it works:**
- On startup, the app checks `config/metrics.yml`
- New metrics (not yet in database) are automatically imported
- Data is fetched from OWID or ILO depending on the source
- Europe and EU-27 aggregates are calculated automatically
- No manual terminal commands needed in production

### Configuration Options

| Field | Description | Required |
|-------|-------------|----------|
| `source` | Data source: `owid` or `ilo` | Yes |
| `owid_slug` | OWID chart slug (for OWID sources) | For OWID |
| `ilo_indicator` | ILO indicator ID (for ILO sources) | For ILO |
| `start_year` | First year of data to import | Yes |
| `end_year` | Last year of data to import | Yes |
| `unit` | Display unit for the metric | Yes |
| `description` | Human-readable description | Yes |
| `category` | One of: economy, social, development, health, environment, innovation | Yes |
| `aggregation_method` | How to calculate Europe aggregate: `population_weighted`, `sum`, or `average` | Yes |
| `enabled` | Set to `false` to disable import | Yes |
| `preferred` | Set to `true` to prioritize over similar metrics | No |

See [ADDING_METRICS_GUIDE.md](ADDING_METRICS_GUIDE.md) for complete instructions.

## Fact Check Articles

The application supports in-depth fact-check articles written in Markdown with YAML frontmatter. Articles are stored in `content/fact_checks/` and support custom embed tags:

### Custom Tags

- `{{metric:metric_name}}` - Renders a metric comparison card with all European groupings
- `{{chart:metric_slug}}` - Renders an interactive chart inline

### Creating Articles

1. Create a markdown file in `content/fact_checks/`:

```markdown
---
title: "Your Article Title"
subtitle: "A compelling subtitle"
description: "Brief description for meta tags"
published: true
created_at: 2026-01-12
metrics:
  - gdp_per_capita_ppp
  - labor_productivity_per_hour
---

## Your Content Here

{{metric:gdp_per_capita_ppp}}

{{chart:labor_productivity_per_hour}}
```

2. The article will automatically appear at `/facts/your-article-slug`

### Features

- **OG Images**: Auto-generated 1200x630 PNG images for social sharing
- **Share Sidebar**: Floating share buttons for Twitter, LinkedIn, Facebook
- **Responsive**: Mobile-optimized with collapsible sections
- **Live Data**: Metrics and charts pull live data from the database


## Contributing

**EuropeVersus is an open source project that thrives on community contributions!** We welcome data contributions, code improvements, translations, and documentation updates.

### Contributing Data Points

We're actively seeking contributors to expand our statistical database. Here's how you can help:

#### Source Requirements

**All data must come from reputable sources only:**

**Accepted Sources:**
- Government statistical agencies (Eurostat, ONS, BLS, etc.)
- International organizations (World Bank, IMF, OECD, UN, WHO, IEA)
- Academic institutions with peer-reviewed research
- Established NGOs with transparent methodologies (Transparency International, Freedom House)

**Not Accepted:**
- News articles or blog posts
- Unverified social media content
- Sources with unclear methodology
- Politically biased organizations
- Commercial entities without transparent methodology

#### Data Contribution Checklist

Before submitting data, ensure:

- [ ] Source is from an approved reputable organization
- [ ] Data includes Europe, US, India, and China (or clearly notes unavailable data)
- [ ] Year of data collection is specified
- [ ] Methodology is transparent and consistent across regions
- [ ] Unit of measurement is clearly defined
- [ ] Source URL is provided and accessible
- [ ] Data has been double-checked for accuracy

### Test Coverage

**Tests:** 256 tests passing, 1,560 assertions, 0 failures, 0 errors  
**Coverage:** 79.47% (1,041/1,310 lines covered)

### Translation Contributions

Help make EuropeVersus accessible to more people:
- Translate the interface to other European languages
- Add localised number formatting

### Documentation

- Improve this README
- Add code comments
- Create tutorials for contributors
- Document data sources and methodologies

## License

This project is open source and available under the [GNU Public License](LICENSE).

## Data Quality & Review Process

### Moderation System

All contributed data goes through a review process:

1. **Automated Validation**: Source domains are checked against approved lists
2. **Community Review**: Contributors can flag questionable data
3. **Maintainer Approval**: Final review by project maintainers
4. **Source Verification**: Links and methodology are verified

### Data Standards

- **Timeliness**: Data should be recent (within 5 years preferred)
- **Consistency**: Same methodology across all compared regions
- **Transparency**: Full source attribution and methodology description
- **Accuracy**: Double-checked against original sources

## Current Data Sources

Statistics are sourced from multiple providers:

- **Our World in Data (OWID)**: Primary source for most metrics - GDP, population, life satisfaction, child mortality, electricity access, and more
- **International Labour Organization (ILO)**: Labor productivity metrics (per hour and per worker)
- **World Bank**: Development indicators via OWID
- **OECD**: PISA education scores via OWID
- **World Health Organization**: Health metrics via OWID

All metrics are configured in `config/metrics.yml`. See [ADDING_METRICS_GUIDE.md](ADDING_METRICS_GUIDE.md) for detailed instructions.

## � Reporting Issues

Found incorrect data or questionable sources?

1. **Data Issues**: Use the "Report Data Issue" feature on any statistic page
2. **Technical Issues**: Open a GitHub issue with the "Bug" template
3. **Source Concerns**: Email maintainers with detailed concerns

## Contact & Community

- **GitHub Issues**: For technical issues and feature requests
- **Discussions**: Use GitHub Discussions for general questions
- **Security**: Email security issues privately to maintainers
- **Data Contributions**: Use the web interface or create an issue

## License

This project is open source and available under the [GNU Public License](LICENSE).

---

**EuropeVersus** - An open source, evidence-based approach to understanding European performance 🇪🇺

*"Better data leads to better decisions. Better decisions lead to better outcomes."*
