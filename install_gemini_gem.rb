# frozen_string_literal: true
#!/usr/bin/env ruby
# install_gemini_gem.rb

require 'fileutils'
require 'yaml'
require 'erb'

class GeminiGemInstaller
  def self.install(gem_name)
    new(gem_name).install
  end

  def initialize(gem_name)
    @gem_name = gem_name
    @root_path = File.expand_path("../#{@gem_name}", __FILE__)
  end

  def install
    create_directory_structure
    write_all_files
    # install_dependencies
    puts "\nGem '#{@gem_name}' has been created successfully!"
    puts "To use it, cd into #{@gem_name} and run: bundle install"
    puts "Remember to set your GEMINI_API_KEY and GOOGLE_APPLICATION_CREDENTIALS (for TTS) environment variables."
    puts "For example: export GEMINI_API_KEY='YOUR_GEMINI_API_KEY'"
    puts "             export GOOGLE_APPLICATION_CREDENTIALS='/path/to/your/google_cloud_service_account.json'"
  end

  private

  def create_directory_structure
    dirs = [
      "",
      "/lib",
      "/lib/#{@gem_name}",
      "/bin",
      "/config",
      "/spec",
      "/spec/#{@gem_name}",
      "/spec/fixtures/vcr_cassettes",
      "/spec/fixtures/audio_files",
      "/extra_scripts/simple_web_app",
      "/extra_scripts/simple_web_app/public/downloads",
      "/extra_scripts/simple_web_app/views"
    ]

    dirs.each do |dir|
      FileUtils.mkdir_p("#{@root_path}#{dir}")
    end
  end

  def write_all_files
    write_gemspec
    write_lib_files
    write_bin_files
    write_config_files
    write_spec_files
    write_readme
    write_additional_scripts
    write_gitignore
  end

  def write_gemspec
    content = <<~GEMSPEC
      # frozen_string_literal: true

      require_relative "lib/#{@gem_name}/version"

      Gem::Specification.new do |spec|
        spec.name = "#{@gem_name}"
        spec.version = #{@gem_name.capitalize}::VERSION
        spec.authors = ["Your Name"]
        spec.email = ["your.email@example.com"]

        spec.summary = "Gemini AI integration gem, focused on music applications."
        spec.description = "A Ruby gem for integrating with Google's Gemini AI models, offering tools for music-related content generation and analysis, including integration with Google Cloud Text-to-Speech."
        spec.homepage = "https://github.com/yourusername/#{@gem_name}"
        spec.license = "MIT"
        spec.required_ruby_version = ">= 2.7.0"

        spec.metadata = {
          "homepage_uri" => spec.homepage,
          "source_code_uri" => spec.homepage,
          "changelog_uri" => "\#{spec.homepage}/blob/main/CHANGELOG.md"
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
    GEMSPEC

    File.write("#{@root_path}/#{@gem_name}.gemspec", content)
  end

  def write_lib_files
    # Version file
    version_content = <<~RUBY
      # frozen_string_literal: true

      module #{@gem_name.capitalize}
        VERSION = "0.1.0"
      end
    RUBY
    File.write("#{@root_path}/lib/#{@gem_name}/version.rb", version_content)

    # Main gem file
    gem_module_content = <<~RUBY
      # frozen_string_literal: true

      require_relative '#{@gem_name}/configuration'
      require_relative '#{@gem_name}/client'
      require_relative '#{@gem_name}/version'

      module #{@gem_name.capitalize}
        class << self
          def client(options = {})
            Client.new(options)
          end
        end
      end
    RUBY
    File.write("#{@root_path}/lib/#{@gem_name}.rb", gem_module_content)


    # Configuration file
    config_content = <<~RUBY
      # frozen_string_literal: true

      require 'logger'
      require 'yaml'
      require 'erb'
      require 'google/cloud/text_to_speech'

      module #{@gem_name.capitalize}
        class Configuration
          attr_accessor :api_key, :api_base, :timeout, :model, :temperature, :max_tokens, :logger, :retry_options, :tts_config

          def initialize
            @api_key = ENV['GEMINI_API_KEY']
            @api_base = "https://generativelanguage.googleapis.com/v1"
            @timeout = 30
            @model = "gemini-pro"
            @temperature = 0.7
            @max_tokens = 1024
            @logger = Logger.new($stdout)
            @logger.level = Logger::INFO
            @retry_options = {
              max: 3,
              interval: 0.05,
              interval_randomness: 0.5,
              backoff_factor: 2,
              exceptions: [Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS, Faraday::ConnectionFailed, Faraday::TimeoutError].flatten.uniq,
              retry_statuses: [429, 500, 502, 503, 504]
            }
            @tts_config = {
              language_code: 'en-US',
              name: 'en-US-Standard-C'
            }

            load_from_yaml
          end

          private

          def load_from_yaml
            config_file = File.expand_path("../../config/config.yml", __dir__)
            return unless File.exist?(config_file)

            begin
              erb_content = ERB.new(File.read(config_file)).result
              config = YAML.safe_load(erb_content, permitted_classes: [Symbol], aliases: true) || {}
              env = ENV['APP_ENV'] || ENV['RACK_ENV'] || 'development'

              if config[env.to_sym]
                env_config = config[env.to_sym]
                @api_base = env_config[:api_base] if env_config[:api_base]
                @timeout = env_config[:timeout] if env_config[:timeout]
                @model = env_config[:model] if env_config[:model]
                @temperature = env_config[:temperature] if env_config[:temperature]
                @max_tokens = env_config[:max_tokens] if env_config[:max_tokens]
                @logger.level = Logger.const_get(env_config[:logger_level].upcase) if env_config[:logger_level]
                @retry_options.merge!(env_config[:retry_options]) if env_config[:retry_options]
                @tts_config.merge!(env_config[:tts_config]) if env_config[:tts_config]
              end
              @logger.info("Configuration loaded for environment: \#{env}")
            rescue Psych::SyntaxError => e
              @logger.error("Error parsing config/config.yml: \#{e.message}")
            rescue StandardError => e
              @logger.error("Error loading configuration from config.yml: \#{e.message}")
            end
          end
        end

        class << self
          attr_writer :configuration

          def configuration
            @configuration ||= Configuration.new
          end

          def configure
            yield(configuration)
          end

          def reset_configuration!
            @configuration = Configuration.new
          end
        end
      end
    RUBY
    File.write("#{@root_path}/lib/#{@gem_name}/configuration.rb", config_content)

    # Client file (completed)
    client_content = <<~RUBY
      # frozen_string_literal: true

      require 'faraday'
      require 'faraday/multipart'
      require 'faraday/retry'
      require 'json'
      require 'base64'
      require 'logger'
      require 'google/cloud/text_to_speech'

      module #{@gem_name.capitalize}
        class Error < StandardError; end
        class AuthenticationError < Error; end
        class RateLimitError < Error; end
        class ContentBlockedError < Error; end

        class Response
          attr_reader :text, :prompt_feedback

          def initialize(text:, prompt_feedback: nil)
            @text = text
            @prompt_feedback = prompt_feedback
          end

          def blocked_by_safety?
            !@prompt_feedback.nil?
          end
        end

        class Client
          attr_reader :connection, :config

          def initialize(api_key: nil)
            @config = #{@gem_name.capitalize}.configuration
            @api_key = api_key || @config.api_key
            raise AuthenticationError, "GEMINI_API_KEY is required" unless @api_key

            @connection = Faraday.new(url: @config.api_base) do |faraday|
              faraday.request :multipart
              faraday.request :retry, @config.retry_options
              faraday.headers['x-goog-api-key'] = @api_key
              faraday.headers['Content-Type'] = 'application/json'
              faraday.options.timeout = @config.timeout
            end
          end

          def generate_content(prompt, **params)
            response = @connection.post("models/\#{@config.model}:generateContent") do |req|
              req.body = {
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: {
                  temperature: params[:temperature] || @config.temperature,
                  maxOutputTokens: params[:max_tokens] || @config.max_tokens
                }
              }.to_json
            end

            handle_response(response)
          end

          def generate_vocals(text, output_file, voice_config = {})
            client = Google::Cloud::TextToSpeech.text_to_speech
            synthesis_input = { text: text }
            voice = { language_code: @config.tts_config[:language_code], name: voice_config[:name] || @config.tts_config[:name] }
            audio_config = { audio_encoding: :MP3 }

            response = client.synthesize_speech(
              input: synthesis_input,
              voice: voice,
              audio_config: audio_config
            )

            File.binwrite(output_file, response.audio_content)
            output_file
          rescue Google::Cloud::Error => e
            raise Error, "TTS Error: \#{e.message}"
          end

          def analyze_image(image_path, prompt)
            image_data = File.binread(image_path)
            encoded_image = Base64.strict_encode64(image_data)
            response = @connection.post("models/gemini-pro-vision:generateContent") do |req|
              req.body = {
                contents: [{
                  parts: [
                    { text: prompt },
                    { inline_data: { mime_type: "image/png", data: encoded_image } }
                  ]
                }]
              }.to_json
            end

            handle_response(response)
          end

          def analyze_audio_metadata(audio_path)
            # Conceptual: Basic metadata extraction
            require 'filemagic'
            fm = FileMagic.new
            metadata = { file_type: fm.file(audio_path), size: File.size(audio_path) }
            prompt = "Analyze the following audio metadata: \#{metadata.to_json}"
            generate_content(prompt)
          end

          private

          def handle_response(response)
            if response.success?
              data = JSON.parse(response.body)
              if data['promptFeedback']&.[]('blockReason')
                raise ContentBlockedError, "Content blocked: \#{data['promptFeedback']['blockReason']}"
              end
              text = data.dig('candidates', 0, 'content', 'parts', 0, 'text') || ""
              Response.new(text: text, prompt_feedback: data['promptFeedback'])
            else
              raise Error, "API request failed: \#{response.status} - \#{response.body}"
            end
          rescue JSON::ParserError
            raise Error, "Invalid API response format"
          end
        end
      end
    RUBY
    File.write("#{@root_path}/lib/#{@gem_name}/client.rb", client_content)
  end

  def write_bin_files
    bin_content = <<~RUBY
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      $LOAD_PATH.unshift File.expand_path('../../lib', __dir__)
      require '#{@gem_name}'
      require 'optparse'

      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: #{@gem_name} [command] [options]"

        opts.on("-o", "--output FILE", "Output file for generated content") do |file|
          options[:output] = file
        end

        opts.on("--voice-lang LANG", "Voice language code (e.g., en-US)") do |lang|
          options[:voice_lang] = lang
        end

        opts.on("--voice-name NAME", "Voice name (e.g., en-US-Wavenet-F)") do |name|
          options[:voice_name] = name
        end
      end.parse!

      command = ARGV.shift
      client = #{@gem_name.capitalize}.client

      begin
        case command
        when "generate-text"
          raise "Prompt required" if ARGV.empty?
          puts client.generate_content(ARGV.join(" ")).text
        when "generate-vocals"
          raise "Output file required: --output FILE" unless options[:output]
          raise "Text required" if ARGV.empty?
          voice_config = { language_code: options[:voice_lang], name: options[:voice_name] }.compact
          client.generate_vocals(ARGV.join(" "), options[:output], voice_config)
          puts "Vocals generated at: \#{options[:output]}"
        when "analyze-image"
          raise "Image file and prompt required" if ARGV.size < 2
          puts client.analyze_image(ARGV[0], ARGV[1..-1].join(" ")).text
        when "analyze-audio"
          raise "Audio file required" if ARGV.empty?
          puts client.analyze_audio_metadata(ARGV[0]).text
        else
          puts "Unknown command: \#{command}"
          puts "Available commands: generate-text, generate-vocals, analyze-image, analyze-audio"
        end
      rescue #{@gem_name.capitalize}::Error, StandardError => e
        puts "Error: \#{e.message}"
        exit 1
      end
    RUBY
    File.write("#{@root_path}/bin/#{@gem_name}", bin_content)
    FileUtils.chmod(0755, "#{@root_path}/bin/#{@gem_name}")
  end

  def write_config_files
    config_yml = <<~YAML
      development:
        api_base: https://generativelanguage.googleapis.com/v1
        timeout: 30
        model: gemini-pro
        temperature: 0.7
        max_tokens: 1024
        logger_level: info
        tts_config:
          language_code: en-US
          name: en-US-Standard-C

      test:
        api_base: https://generativelanguage.googleapis.com/v1
        timeout: 5
        model: gemini-pro
        temperature: 0.7
        max_tokens: 10
        logger_level: error
        tts_config:
          language_code: en-US
          name: en-US-Standard-C
    YAML
    File.write("#{@root_path}/config/config.yml", config_yml)
  end

  def write_spec_files
    spec_helper = <<~RUBY
      # frozen_string_literal: true

      require 'webmock/rspec'
      require 'vcr'
      require '#{@gem_name}'

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
    RUBY
    File.write("#{@root_path}/spec/spec_helper.rb", spec_helper)

    client_spec = <<~RUBY
      # frozen_string_literal: true

      require 'spec_helper'

      RSpec.describe #{@gem_name.capitalize}::Client, :vcr do
        subject(:client) { described_class.new(api_key: 'test-api-key') }

        describe '#generate_content' do
          it 'generates text content' do
            response = client.generate_content("Write a short lyric")
            expect(response).to be_a(#{@gem_name.capitalize}::Response)
            expect(response.text).to include("love") # VCR cassette dependent
          end
        end

        describe '#generate_vocals' do
          let(:output_file) { "spec/fixtures/audio_files/test.mp3" }

          before do
            # Mock the Google Cloud TTS client
            mock_tts_client = instance_double(Google::Cloud::TextToSpeech::V1::TextToSpeech::Client)
            mock_response = instance_double(Google::Cloud::TextToSpeech::V1::SynthesizeSpeechResponse, audio_content: "fake-mp3-data")
            allow(Google::Cloud::TextToSpeech).to receive(:text_to_speech).and_return(mock_tts_client)
            allow(mock_tts_client).to receive(:synthesize_speech).and_return(mock_response)
          end

          it 'generates an MP3 file' do
            result = client.generate_vocals("Hello, world!", output_file)
            expect(File.exist?(result)).to be true
            expect(File.read(result)).to eq("fake-mp3-data")
          end
        end

        describe '#analyze_image' do
          let(:image_path) { "spec/fixtures/test_image.png" }
          before do
            FileUtils.touch(image_path) # Create a dummy image file
          end
          after do
            FileUtils.rm(image_path)
          end

          it 'analyzes an image' do
            response = client.analyze_image(image_path, "what is this?")
            expect(response.text).to include("A black square") # VCR cassette dependent
          end
        end
      end
    RUBY
    File.write("#{@root_path}/spec/#{@gem_name}/client_spec.rb", client_spec)
  end

  def write_readme
    readme = <<~MARKDOWN
      # #{@gem_name.capitalize}

      A Ruby gem for integrating with Google's Gemini AI models, offering tools for music-related content generation and analysis, including integration with Google Cloud Text-to-Speech.

      ## Installation

      Add this line to your application's Gemfile:
      ```ruby
      gem '#{@gem_name}'
      ```

      And then execute:
      ```bash
      $ bundle install
      ```

      Or install it yourself as:
      ```bash
      $ gem install #{@gem_name}
      ```

      ## Setup

      Set environment variables:

      ```bash
      export GEMINI_API_KEY="your-gemini-api-key"
      # Required for vocal generation
      export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/google_cloud_service_account.json"
      ```

      ## Usage

      ### Command Line

      ```bash
      #{@gem_name} generate-text "Write a short lyric"
      #{@gem_name} generate-vocals "Hello, world!" --output vocals.mp3 --voice-name en-US-Wavenet-F
      #{@gem_name} analyze-image album-art.png "Describe the music style"
      #{@gem_name} analyze-audio song.mp3
      ```

      ### Web App

      A simple Sinatra web app is included in the `extra_scripts` directory.

      ```bash
      cd extra_scripts/simple_web_app
      bundle install
      ruby app.rb
      ```

      Visit `http://localhost:4567`.

      ## Development

      After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

    MARKDOWN
    File.write("#{@root_path}/README.md", readme)
  end

  def write_additional_scripts
    app_rb = <<~RUBY
      # frozen_string_literal: true

      require 'sinatra'
      require 'sinatra/reloader' if development?
      require 'fileutils'
      require 'securerandom'
      require 'logger'
      require '#{@gem_name}'

      # Configure MyMusicGem
      #{@gem_name.capitalize}.configure do |config|
        config.logger = Logger.new(STDOUT)
        config.logger.level = Logger::INFO
      end

      # Setup a client instance
      # Note: For a real app, you might manage the client instance differently
      $mymusic_client = #{@gem_name.capitalize}.client rescue nil

      # Directory to store generated files
      DOWNLOADS_DIR = File.join(__dir__, 'public', 'downloads')
      FileUtils.mkdir_p(DOWNLOADS_DIR) unless File.directory?(DOWNLOADS_DIR)

      # Configure Sinatra settings
      set :erb, escape_html: true
      set :public_folder, File.join(__dir__, 'public')
      set :views, File.join(__dir__, 'views')

      before do
        # Check for API key on every request
        unless $mymusic_client
          @error = "GEMINI_API_KEY environment variable not set. The application will not work."
        end
      end

      get '/' do
        erb :index
      end

      post '/generate_lyrics' do
        prompt = params[:prompt]
        begin
          response = $mymusic_client.generate_content(prompt)
          if response.blocked_by_safety?
            @error = "Content blocked by safety filters. Feedback: \#{response.prompt_feedback}"
          else
            @result = response.text
          end
        rescue #{@gem_name.capitalize}::Error => e
          @error = "API Error: \#{e.message}"
        rescue StandardError => e
          @error = "An unexpected error occurred: \#{e.message}"
        end
        erb :index
      end

      post '/generate_vocals' do
        text = params[:text]
        voice_name = params[:voice_name]
        output_filename = "vocals_\#{SecureRandom.hex(8)}.mp3"
        output_file_path = File.join(DOWNLOADS_DIR, output_filename)
        begin
          raise "Google Cloud credentials not set. GOOGLE_APPLICATION_CREDENTIALS must be configured." unless ENV['GOOGLE_APPLICATION_CREDENTIALS']
          voice_config = voice_name.empty? ? {} : { name: voice_name }
          generated_file = $mymusic_client.generate_vocals(text, output_file_path, voice_config)
          @result = "Vocals generated successfully!"
          @audio_link = "/downloads/\#{File.basename(generated_file)}"
        rescue #{@gem_name.capitalize}::Error => e
          @error = "Error generating vocals: \#{e.message}"
        rescue StandardError => e
          @error = "An unexpected error occurred: \#{e.message}"
        end
        erb :index
      end

      error do
        "An error occurred: \#{env['sinatra.error'].message}"
      end
    RUBY
    File.write("#{@root_path}/extra_scripts/simple_web_app/app.rb", app_rb)

    index_erb = <<~ERB
      <!DOCTYPE html>
      <html>
      <head>
        <title>#{@gem_name.capitalize} Web Demo</title>
        <style>
          body { font-family: sans-serif; margin: 2em; line-height: 1.5; }
          form { margin-bottom: 2em; padding: 1em; border: 1px solid #ccc; border-radius: 8px; }
          label { display: block; margin-bottom: .5em; font-weight: bold; }
          input[type="text"], textarea { width: 90%; max-width: 600px; padding: 8px; margin-bottom: 1em; border: 1px solid #ddd; border-radius: 4px; }
          input[type="submit"] { padding: 10px 20px; background-color: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer; }
          .result { background-color: #f0f0f0; padding: 1em; border-radius: 5px; margin-top: 1em; white-space: pre-wrap; word-break: break-word; }
          .error { color: red; font-weight: bold; background-color: #fee; padding: 1em; border-radius: 5px; }
        </style>
      </head>
      <body>
        <h1>#{@gem_name.capitalize} Web Demo</h1>

        <% if @error %>
          <div class="error">
            <h3>Error:</h3>
            <pre><%= @error %></pre>
          </div>
        <% end %>

        <form action="/generate_lyrics" method="post">
          <h2>Generate Lyrics</h2>
          <label for="prompt">Prompt for Lyrics:</label>
          <textarea id="prompt" name="prompt" rows="4" required>Write a short, catchy chorus for a pop song about summer love</textarea><br>
          <input type="submit" value="Generate Lyrics">
        </form>

        <form action="/generate_vocals" method="post">
          <h2>Generate Vocals (Audio)</h2>
          <p><strong>Note:</strong> Requires `GOOGLE_APPLICATION_CREDENTIALS` to be set.</p>
          <label for="vocals_text">Text for Vocals:</label>
          <textarea id="vocals_text" name="text" rows="2" required>Oh, the summer breeze, it sings to me.</textarea><br>
          <label for="vocals_voice">Voice Name (e.g., en-US-Wavenet-F, see <a href="https://cloud.google.com/text-to-speech/docs/voices" target="_blank">Google Cloud Voices</a>):</label>
          <input type="text" id="vocals_voice" name="voice_name" value="en-US-Standard-C"><br>
          <input type="submit" value="Generate Vocals">
        </form>

        <% if @result %>
          <div class="result">
            <h3>Result:</h3>
            <p><%= @result %></p>
            <% if @audio_link %>
              <p>
                <audio controls src="<%= @audio_link %>">
                  Your browser does not support the audio element.
                </audio>
              </p>
              <p><a href="<%= @audio_link %>" download>Download Audio</a></p>
            <% end %>
          </div>
        <% end %>

      </body>
      </html>
    ERB
    File.write("#{@root_path}/extra_scripts/simple_web_app/views/index.erb", index_erb)

    config_ru = <<~RUBY
      # frozen_string_literal: true
      require_relative 'app'
      run Sinatra::Application
    RUBY
    File.write("#{@root_path}/extra_scripts/simple_web_app/config.ru", config_ru)

    gemfile = <<~RUBY
      source 'https://rubygems.org'

      gem 'sinatra', '~> 3.0'
      gem 'sinatra-reloader'
      gem '#{@gem_name}', path: '../../'
    RUBY
    File.write("#{@root_path}/extra_scripts/simple_web_app/Gemfile", gemfile)

    File.write("#{@root_path}/extra_scripts/simple_web_app/public/downloads/.gitkeep", "")
  end

  def install_dependencies
    puts "--- Installing dependencies for the gem ---"
    Dir.chdir(@root_path) do
      system("bundle config set --local path 'vendor/bundle' && bundle install")
    end
    puts "\n--- Installing dependencies for the web app ---"
    Dir.chdir("#{@root_path}/extra_scripts/simple_web_app") do
      system("bundle config set --local path 'vendor/bundle' && bundle install")
    end
  end
  def write_gitignore
    content = <<~GITIGNORE
      # Ignore bundler config.
      /.bundle

      # Ignore local gem installations.
      /vendor/bundle

      # Ignore generated files.
      /spec/fixtures/audio_files/
    GITIGNORE
    File.write("#{@root_path}/.gitignore", content)
  end
end

if ARGV.empty?
  puts "Usage: ruby install_gemini_gem.rb <gem_name>"
  exit 1
end

GeminiGemInstaller.install(ARGV[0])
