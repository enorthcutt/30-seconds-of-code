# frozen_string_literal: true

require_relative "lib/mymusicgem/version"

Gem::Specification.new do |spec|
  spec.name = "mymusicgem"
  spec.version = Mymusicgem::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Gemini AI integration gem, focused on music applications."
  spec.description = "A Ruby gem for integrating with Google's Gemini AI models, offering tools for music-related content generation and analysis, including integration with Google Cloud Text-to-Speech."
  spec.homepage = "https://github.com/yourusername/mymusicgem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  spec.files = Dir["{lib,bin,config,extra_scripts,spec}/**/*", "README.md", "LICENSE.txt"]
  spec.bindir = "bin"
  spec.executables = Dir["bin/*"].map { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Production dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "logger", "~> 1.0"
  spec.add_dependency "google-cloud-text_to_speech", "~> 1.0"
  spec.add_dependency "sinatra", "~> 3.0" # Corrected from 'sinatras'

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rack-test", "~> 2.0"
end
