# Mymusicgem

A Ruby gem for integrating with Google's Gemini AI models, offering tools for music-related content generation and analysis, including integration with Google Cloud Text-to-Speech.

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'mymusicgem'
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install mymusicgem
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
mymusicgem generate-text "Write a short lyric"
mymusicgem generate-vocals "Hello, world!" --output vocals.mp3 --voice-name en-US-Wavenet-F
mymusicgem analyze-image album-art.png "Describe the music style"
mymusicgem analyze-audio song.mp3
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
