ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Default to serial execution for compatibility across local environments.
  # Set PARALLEL_TEST_WORKERS to enable parallel workers explicitly.
  workers = ENV.fetch("PARALLEL_TEST_WORKERS", "0").to_i
  parallelize(workers: workers) if workers.positive?

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
