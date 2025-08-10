# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mymusicgem::Client, :vcr do
  subject(:client) { described_class.new(api_key: 'test-api-key') }

  describe '#generate_content' do
    it 'generates text content' do
      response = client.generate_content("Write a short lyric")
      expect(response).to be_a(Mymusicgem::Response)
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
