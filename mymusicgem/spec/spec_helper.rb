# frozen_string_literal: true

require 'webmock/rspec'
require 'vcr'
require 'mymusicgem'

# Set a dummy API key for tests
ENV['GEMINI_API_KEY'] ||= 'test-api-key'

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<GEMINI_API_KEY>') { ENV['GEMINI_API_KEY'] }
  config.configure_rspec_metadata!
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    # Create necessary directories
    FileUtils.mkdir_p("spec/fixtures/audio_files")
  end

  config.after(:suite) do
    # Clean up generated files
    FileUtils.rm_rf("spec/fixtures/audio_files")
  end
end
