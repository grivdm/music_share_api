class SpotifyService < MusicPlatformService
  include ApiErrorHandling
  BASE_API_URL = "https://api.spotify.com/v1".freeze
  AUTH_URL = "https://accounts.spotify.com/api/token".freeze
  PLATFORM = :spotify

  attr_reader :access_token

  def get_track_from_url(url)
    track_id = parse_track_url(url)
    get_track_by_id(track_id)
  end

  def get_track_by_id(id)
    ensure_token

    response = HTTParty.get(
      "#{BASE_API_URL}/tracks/#{id}",
      headers: authorization_header
    )

    if response.success?
      parse_track_data(response.parsed_response)
    else
      handle_error(response)
    end
  end

  def search_track_by_isrc(isrc)
    ensure_token

    response = HTTParty.get(
      "#{BASE_API_URL}/search",
      query: { q: "isrc:#{isrc}", type: "track", limit: 1 },
      headers: authorization_header
    )

    if response.success? && response["tracks"]["items"].any?
      parse_track_data(response["tracks"]["items"][0])
    else
      handle_error(response)
      nil
    end
  end

  def search_track(artist, title)
    ensure_token

    query = "artist:#{artist} track:#{title}"
    response = HTTParty.get(
      "#{BASE_API_URL}/search",
      query: { q: query, type: "track", limit: 1 },
      headers: authorization_header
    )

    if response.success? && response["tracks"]["items"].any?
      parse_track_data(response["tracks"]["items"][0])
    else
      handle_error(response)
      nil
    end
  end

  def get_track_url(track_id)
    "https://open.spotify.com/track/#{track_id}"
  end

  private

  def configure(*args)
    @client_id = ENV["SPOTIFY_CLIENT_ID"]
    @client_secret = ENV["SPOTIFY_CLIENT_SECRET"]
    @access_token = nil
    @token_expires_at = nil
  end

  def parse_track_url(url)
    # https://open.spotify.com/track/{id}
    # or https://open.spotify.com/track/{id}?si={some_param}
    match = url.match(/spotify\.com\/track\/([^?]+)/)
    match[1] if match
  end

  def parse_track_data(data)
    {
      isrc: data.dig("external_ids", "isrc"),
      title: data["name"],
      artist: data["artists"].map { |a| a["name"] }.join(", "),
      album: data.dig("album", "name"),
      platform_id: data["id"],
      url: data["external_urls"]["spotify"],
      platform: PLATFORM
    }
  end

  def ensure_token
    return if @access_token && @token_expires_at && @token_expires_at > Time.now

    if @client_id.blank? || @client_secret.blank?
      raise Error, "Spotify credentials are missing."
    end

    auth_response = HTTParty.post(
      AUTH_URL,
      body: { grant_type: "client_credentials" },
      headers: {
        "Authorization" => "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}"
      }
    )

    if auth_response.success?
      @access_token = auth_response["access_token"]
      @token_expires_at = Time.now + auth_response["expires_in"].to_i.seconds
    else
      Rails.logger.error "Spotify auth error: #{auth_response.code} #{auth_response.message} #{auth_response.body}"
      raise Error, "Failed to obtain Spotify access token: #{auth_response.code} #{auth_response.message}"
    end
  end

  def authorization_header
    ensure_token
    { "Authorization" => "Bearer #{@access_token}" }
  end

  def handle_error(response)
    handle_api_error(response, "Spotify")
  end
end
