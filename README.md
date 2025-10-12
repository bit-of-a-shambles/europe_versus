# EuropeVersus 🇪🇺

An **open source** Rails 8 web application that provides evidence-based comparisons between European statistics and those of the United States, India, and China. This project aims to counter negative narratives about Europe by presenting factual data in an accessible, visual format.

## 🎯 Mission

EuropeVersus promotes data-driven understanding of European performance across multiple dimensions. Too often, discussions about Europe focus on challenges without acknowledging the continent's remarkable achievements in quality of life, social progress, and sustainable development.

**This is an open source, community-driven project.** We believe that accurate data should be freely accessible and continuously improved by contributors worldwide.

## ✨ Features

- **📊 Comprehensive Statistics**: Compare Europe with the US, India, and China across economics, social indicators, environment, and innovation
- **🎨 Beautiful Visualizations**: Clean, responsive design with interactive comparison charts
- **📱 Mobile-First**: Optimized for all devices with Tailwind CSS
- **⚡ Fast & Modern**: Built with Rails 8, Turbo, SQLite, and minimal JavaScript
- **🔍 Evidence-Based**: All data sourced from official statistics and reputable international organizations

## 🏗️ Tech Stack

- **Backend**: Ruby on Rails 8
- **Frontend**: Tailwind CSS, Turbo, Stimulus
- **Database**: SQLite
- **Deployment**: Docker-ready with Kamal configuration

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3.0 or higher
- Rails 8

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd europeversus
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup the database**
   ```bash
   bin/rails db:setup
   ```

4. **Start the development server**
   ```bash
   bin/dev
   ```

5. **Visit the application**
   Open [http://localhost:3000](http://localhost:3000) in your browser

## 📁 Project Structure

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── home_controller.rb          # Homepage with overview
│   └── statistics_controller.rb    # Statistics listing and details
├── models/
│   └── statistic.rb               # Data model for comparisons
├── views/
│   ├── layouts/
│   │   └── application.html.erb   # Main layout with navigation
│   ├── home/
│   │   └── index.html.erb         # Homepage with key stats preview
│   └── statistics/
│       ├── index.html.erb         # All statistics by category
│       └── show.html.erb          # Individual statistic details
└── javascript/
    └── controllers/
        └── mobile_menu_controller.js  # Stimulus controller for mobile nav
```

## 📊 Data Categories

The application currently includes statistics across four main categories:

### 🏦 Economy
- GDP per Capita (PPP)
- GDP Growth Rate
- Unemployment Rate

### 👥 Social
- Life Expectancy
- Education Index
- Social Progress Index

### 🌍 Environment
- CO2 Emissions per Capita
- Renewable Energy Share
- Environmental Performance Index

### 💡 Innovation
- Global Innovation Index
- R&D Spending (% of GDP)

## 🛠️ Development

### Running Tests
```bash
bin/rails test
```

### Database Commands
```bash
# Create and migrate database
bin/rails db:create db:migrate

# Seed with sample data
bin/rails db:seed

# Reset database
bin/rails db:reset
```

### Asset Compilation
```bash
# Build Tailwind CSS
bin/rails tailwindcss:build

# Watch for changes (in development)
bin/rails tailwindcss:watch
```

## 🚢 Deployment

The application is configured for deployment with Kamal and includes:

- Docker configuration
- GitHub Actions CI/CD pipeline
- SSL/TLS ready
- Environment-specific configurations

### Deploy with Kamal
```bash
kamal setup
kamal deploy
```

## 🤝 Contributing

**EuropeVersus is an open source project that thrives on community contributions!** We welcome data contributions, code improvements, translations, and documentation updates.

### 📊 Contributing Data Points

We're actively seeking contributors to expand our statistical database. Here's how you can help:

#### 🔍 Source Requirements

**All data must come from reputable sources only:**

✅ **Accepted Sources:**
- Government statistical agencies (Eurostat, ONS, BLS, etc.)
- International organizations (World Bank, IMF, OECD, UN, WHO, IEA)
- Academic institutions with peer-reviewed research
- Established NGOs with transparent methodologies (Transparency International, Freedom House)

❌ **Not Accepted:**
- News articles or blog posts
- Unverified social media content
- Sources with unclear methodology
- Politically biased organizations
- Commercial entities without transparent methodology

#### 📝 How to Submit Data

**Option 1: Use the Web Interface (Recommended)**
1. Visit the application at `/contribute`
2. Fill out the data submission form
3. Include all required source information
4. Your submission will be reviewed by maintainers

**Option 2: GitHub Issue**
1. Open a new issue with the "Data Contribution" template
2. Provide the statistic details and source information
3. Maintainers will review and add the data

**Option 3: Pull Request**
1. Fork the repository
2. Add data to `db/seeds.rb` following the existing format
3. Include source verification in your PR description
4. Submit for review

#### ✅ Data Contribution Checklist

Before submitting data, ensure:

- [ ] Source is from an approved reputable organization
- [ ] Data includes Europe, US, India, and China (or clearly notes unavailable data)
- [ ] Year of data collection is specified
- [ ] Methodology is transparent and consistent across regions
- [ ] Unit of measurement is clearly defined
- [ ] Source URL is provided and accessible
- [ ] Data has been double-checked for accuracy

### 🛠️ Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### 🌐 Translation Contributions

Help make EuropeVersus accessible to more people:
- Translate the interface to other European languages
- Ensure cultural sensitivity in data presentation
- Add localized number formatting

### 📖 Documentation

- Improve this README
- Add code comments
- Create tutorials for contributors
- Document data sources and methodologies

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## � Data Quality & Review Process

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

## 🙏 Current Data Sources

All statistics are currently sourced from reputable international organizations:

**Economic Data:**
- Our World in Data (aggregating World Bank, Eurostat, OECD, IMF data)
- World Bank - World Development Indicators
- International Monetary Fund (IMF) - World Economic Outlook
- Organisation for Economic Co-operation and Development (OECD)

**Social Indicators:**
- World Health Organization (WHO)
- United Nations Development Programme (UNDP)
- Social Progress Imperative

**Environmental Data:**
- International Energy Agency (IEA)
- Yale Environmental Performance Index
- Global Carbon Atlas

**Innovation Metrics:**
- World Intellectual Property Organization (WIPO)
- Cornell University, INSEAD, WIPO - Global Innovation Index

## � Reporting Issues

Found incorrect data or questionable sources?

1. **Data Issues**: Use the "Report Data Issue" feature on any statistic page
2. **Technical Issues**: Open a GitHub issue with the "Bug" template
3. **Source Concerns**: Email maintainers with detailed concerns

## 📧 Contact & Community

- **GitHub Issues**: For technical issues and feature requests
- **Discussions**: Use GitHub Discussions for general questions
- **Security**: Email security issues privately to maintainers
- **Data Contributions**: Use the web interface or create an issue

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**EuropeVersus** - An open source, evidence-based approach to understanding European performance 🇪🇺

*"Better data leads to better decisions. Better decisions lead to better outcomes."*
