# Start SimpleCov before loading any application code
require "simplecov"

# Configure SimpleCov for parallel tests
SimpleCov.start "rails" do
  add_filter "/bin/"
  add_filter "/db/"
  add_filter "/script/"
  add_filter "/vendor/"
  add_filter "/tmp/"
  add_filter "/config/"
  add_filter "/test/"
  
  add_group "Services", "app/services"
  add_group "Helpers", "app/helpers"
  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  
  # For parallel tests, use unique command names per process
  if ENV["TEST_ENV_NUMBER"]
    command_name "test:#{ENV['TEST_ENV_NUMBER']}"
  else
    command_name "test:#{Process.pid}"
  end
  
  # Merge results from all parallel processes
  merge_timeout 3600
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)
    
    # Setup for SimpleCov with parallel tests
    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end
    
    parallelize_teardown do |worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
