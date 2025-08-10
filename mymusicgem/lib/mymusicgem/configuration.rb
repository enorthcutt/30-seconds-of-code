# frozen_string_literal: true

require 'logger'
require 'yaml'
require 'erb'
require 'google/cloud/text_to_speech'

module Mymusicgem
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
        @logger.info("Configuration loaded for environment: #{env}")
      rescue Psych::SyntaxError => e
        @logger.error("Error parsing config/config.yml: #{e.message}")
      rescue StandardError => e
        @logger.error("Error loading configuration from config.yml: #{e.message}")
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
