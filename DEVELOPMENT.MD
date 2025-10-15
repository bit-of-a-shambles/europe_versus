# 🛠️ Development

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

### Running Tests
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/services/european_metrics_service_test.rb

# Run tests and open coverage report
bin/rails coverage:report
```

### Code Coverage

SimpleCov is configured to track code coverage. After running tests:

```bash
# View coverage report
bin/rails coverage:show

# Or open directly
open coverage/index.html

# Clean old coverage reports
bin/rails coverage:clean
```

The coverage report shows:
- Overall line coverage percentage
- Coverage by file and by component group
- Untested lines highlighted in red
- Fully tested lines in green

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



### Testing
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/services/owid_metric_importer_test.rb
```

### OWID Metrics Management
```bash
# List all configured metrics
bin/rails owid:list

# Import a single metric
bin/rails "owid:import[metric_name]"

# Import all metrics
bin/rails owid:import_all

# Show statistics for a metric
bin/rails "owid:stats[metric_name]"

# Generate config template for new metric
bin/rails "owid:scaffold[metric_name,owid-slug]"
```