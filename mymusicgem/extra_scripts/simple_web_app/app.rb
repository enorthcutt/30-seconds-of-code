# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'fileutils'
require 'securerandom'
require 'logger'
require 'mymusicgem'

# Configure MyMusicGem
Mymusicgem.configure do |config|
  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::INFO
end

# Setup a client instance
# Note: For a real app, you might manage the client instance differently
$mymusic_client = Mymusicgem.client rescue nil

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
      @error = "Content blocked by safety filters. Feedback: #{response.prompt_feedback}"
    else
      @result = response.text
    end
  rescue Mymusicgem::Error => e
    @error = "API Error: #{e.message}"
  rescue StandardError => e
    @error = "An unexpected error occurred: #{e.message}"
  end
  erb :index
end

post '/generate_vocals' do
  text = params[:text]
  voice_name = params[:voice_name]
  output_filename = "vocals_#{SecureRandom.hex(8)}.mp3"
  output_file_path = File.join(DOWNLOADS_DIR, output_filename)
  begin
    raise "Google Cloud credentials not set. GOOGLE_APPLICATION_CREDENTIALS must be configured." unless ENV['GOOGLE_APPLICATION_CREDENTIALS']
    voice_config = voice_name.empty? ? {} : { name: voice_name }
    generated_file = $mymusic_client.generate_vocals(text, output_file_path, voice_config)
    @result = "Vocals generated successfully!"
    @audio_link = "/downloads/#{File.basename(generated_file)}"
  rescue Mymusicgem::Error => e
    @error = "Error generating vocals: #{e.message}"
  rescue StandardError => e
    @error = "An unexpected error occurred: #{e.message}"
  end
  erb :index
end

error do
  "An error occurred: #{env['sinatra.error'].message}"
end
