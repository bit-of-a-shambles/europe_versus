# SimpleCov configuration
require "simplecov-badge"

SimpleCov.start "rails" do
  # Generate coverage badge
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::BadgeFormatter
  ])
  
  # Directories to exclude from coverage
  add_filter "/bin/"
  add_filter "/db/"
  add_filter "/script/"
  add_filter "/vendor/"
  add_filter "/tmp/"
  add_filter "/config/"
  add_filter "/test/"
  
  # Group coverage reports by logical components
  add_group "Services", "app/services"
  add_group "Helpers", "app/helpers"
  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  
  # Track all files, even those not touched by tests
  track_files "{app,lib}/**/*.rb"
  
  # Set minimum coverage thresholds (optional - uncomment to enforce)
  # minimum_coverage 80
  # minimum_coverage_by_file 60
  
  # Refuse coverage drops below threshold
  # refuse_coverage_drop :line, 0.5
end
