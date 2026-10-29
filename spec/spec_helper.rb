# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  skip "/spec/"
  enable_coverage :branch
  minimum_coverage line: 90
end

require "bitgram"
Dir[File.join(__dir__, "support/**/*.rb")].each { |path| require path }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
