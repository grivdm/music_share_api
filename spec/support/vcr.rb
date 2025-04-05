require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "tmp/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = true  # Allow HTTP requests when no cassette is in use

  config.filter_sensitive_data('<YOUTUBE_API_KEY>') { ENV['YOUTUBE_API_KEY'] }
  config.filter_sensitive_data('<SPOTIFY_CLIENT_ID>') { ENV['SPOTIFY_CLIENT_ID'] }
  config.filter_sensitive_data('<SPOTIFY_CLIENT_SECRET>') { ENV['SPOTIFY_CLIENT_SECRET'] }
  config.filter_sensitive_data('<BEARER_TOKEN>') { |interaction|
    if interaction.request.headers['Authorization']&.first =~ /^Bearer /
      interaction.request.headers['Authorization'].first.gsub(/Bearer (.+)/, 'Bearer <BEARER_TOKEN>')
    end
  }
  config.filter_sensitive_data('<BASIC_AUTH>') { |interaction|
    if interaction.request.headers['Authorization']&.first =~ /^Basic /
      interaction.request.headers['Authorization'].first.gsub(/Basic (.+)/, 'Basic <BASIC_AUTH>')
    end
  }
  config.filter_sensitive_data('<AUTH_HEADER>') { |interaction|
    interaction.request.headers['Authorization']&.first if interaction.request.headers['Authorization']
  }

  config.filter_sensitive_data('<ACCESS_TOKEN>') do |interaction|
    begin
      if interaction.response.body && interaction.response.headers['Content-Type']&.first&.include?('application/json')
        body = JSON.parse(interaction.response.body)
        body['access_token'] if body.is_a?(Hash) && body['access_token']
      end
    rescue JSON::ParserError
      nil
    end
  end
end
