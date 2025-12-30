# EuropeVersus 🇪🇺

![Test Coverage](https://img.shields.io/badge/coverage-28.2%25-red)

An **open source** Rails 8 web application that provides evidence-based comparisons between European statistics and those of the United States, India, and China. This project aims to counter negative narratives about Europe by presenting factual data in an accessible, visual format.

## Mission

EuropeVersus promotes data-driven understanding of European performance across multiple dimensions. Too often, discussions about Europe focus on challenges without acknowledging the continent's remarkable achievements in quality of life, social progress, and sustainable development.

**This is an open source, community-driven project.** We believe that accurate data should be freely accessible and continuously improved by contributors worldwide.

## Features

- **Comprehensive Statistics**: Compare Europe with the US, India, and China across economics, social indicators, environment, and innovation
- **Beautiful Visualizations**: Clean, responsive design with interactive comparison charts
- **Mobile-First**: Optimized for all devices with Tailwind CSS
- **Fast & Modern**: Built with Rails 8, Turbo, SQLite, and minimal JavaScript
- **Evidence-Based**: All data sourced from official statistics and reputable international organizations

## Tech Stack

- **Backend**: Ruby on Rails 8
- **Frontend**: Tailwind CSS, Turbo, Stimulus
- **Database**: SQLite
- **Deployment**: Docker-ready with Kamal configuration


## Data Categories

The application includes statistics across four main categories, with data sourced from Our World in Data and other reputable sources:

### Economy
- GDP per Capita (PPP)
- GDP Growth Rate
- Unemployment Rate

### Social
- Life Expectancy
- Life Satisfaction (Cantril Ladder)
- Health Expenditure (% of GDP)
- Education Index
- Social Progress Index

### Environment
- CO2 Emissions per Capita
- Renewable Energy Share
- Environmental Performance Index
- Electricity Access

### Innovation
- Global Innovation Index
- R&D Spending (% of GDP)

## Adding New Metrics

**Zero-terminal workflow!** Just edit a YAML file and deploy.

1. **Add to `config/owid_metrics.yml`:**
   ```yaml
   renewable_energy:
     owid_slug: renewable-energy-consumption
     start_year: 1990
     end_year: 2024
     unit: "terawatt-hours"
     description: "Renewable energy consumption"
     aggregation_method: population_weighted
     enabled: true
   ```

2. **Commit and push:**
   ```bash
   git add config/owid_metrics.yml
   git commit -m "Add renewable energy metric"
   git push
   ```

3. **Deploy** → The app automatically imports new metrics on startup!

See [ADDING_METRICS_GUIDE.md](ADDING_METRICS_GUIDE.md) for complete instructions. For detailed setup and development information, see [DATA_SETUP.md](DATA_SETUP.md).

**How it works:**
- On startup, the app checks `config/owid_metrics.yml`
- New metrics (not yet in database) are automatically imported
- Data is fetched from OWID and Europe/EU-27 aggregates are calculated
- No manual terminal commands needed in production


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

**Current Test Coverage:** 28.2% (304/1078 lines covered)

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

All statistics are currently sourced from Our World in Data.

See [ADDING_METRICS_GUIDE.md](ADDING_METRICS_GUIDE.md) for detailed instructions.

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
