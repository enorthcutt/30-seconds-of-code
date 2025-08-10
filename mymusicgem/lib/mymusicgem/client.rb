# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'json'
require 'base64'
require 'logger'
require 'google/cloud/text_to_speech'

module Mymusicgem
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
      @config = Mymusicgem.configuration
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
      response = @connection.post("models/#{@config.model}:generateContent") do |req|
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
      raise Error, "TTS Error: #{e.message}"
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
      prompt = "Analyze the following audio metadata: #{metadata.to_json}"
      generate_content(prompt)
    end

    private

    def handle_response(response)
      if response.success?
        data = JSON.parse(response.body)
        if data['promptFeedback']&.[]('blockReason')
          raise ContentBlockedError, "Content blocked: #{data['promptFeedback']['blockReason']}"
        end
        text = data.dig('candidates', 0, 'content', 'parts', 0, 'text') || ""
        Response.new(text: text, prompt_feedback: data['promptFeedback'])
      else
        raise Error, "API request failed: #{response.status} - #{response.body}"
      end
    rescue JSON::ParserError
      raise Error, "Invalid API response format"
    end
  end
end
