class YoutubeMusicService < MusicPlatformService
  BASE_API_URL = "https://www.googleapis.com/youtube/v3".freeze
  PLATFORM = :youtube_music

  def get_track_from_url(url)
    video_id = parse_track_url(url)
    return nil unless video_id
    get_track_by_id(video_id)
  end

  def get_track_by_id(id)
    return nil unless id.present?

    # The YouTube API requires an API key, ensure it's set in the environment
    api_key = ENV["YOUTUBE_API_KEY"]
    raise Error, "YouTube API key is missing" unless api_key.present?

    response = HTTParty.get(
      "#{BASE_API_URL}/videos",
      query: {
        id: id,
        part: "snippet,contentDetails",
        key: api_key
      }
    )

    if response.success? && response["items"].present?
      parse_track_data(response["items"][0])
    else
      handle_error(response)
      nil
    end
  end

  def search_track_by_isrc(isrc)
    return nil unless isrc.present?

    api_key = ENV["YOUTUBE_API_KEY"]
    raise Error, "YouTube API key is missing" unless api_key.present?

    response = HTTParty.get(
      "#{BASE_API_URL}/search",
      query: {
        q: "#{isrc}",
        part: "snippet",
        type: "video",
        videoCategoryId: "10", # Music category
        maxResults: 1,
        key: api_key
      }
    )

    if response.success? && response["items"].present?
      video_id = response["items"][0]["id"]["videoId"]
      get_track_by_id(video_id)
    else
      nil
    end
  end

  def search_track(artist, title)
    return nil unless artist.present? && title.present?

    api_key = ENV["YOUTUBE_API_KEY"]
    raise Error, "YouTube API key is missing" unless api_key.present?

    query = "#{artist} #{title} official audio"
    response = HTTParty.get(
      "#{BASE_API_URL}/search",
      query: {
        q: query,
        part: "snippet",
        type: "video",
        videoCategoryId: "10", # Music category
        maxResults: 5,
        key: api_key
      }
    )

    if response.success? && response["items"].present?
      # Find the best match from returned results
      best_match = find_best_match(response["items"], artist, title)
      if best_match
        video_id = best_match["id"]["videoId"]
        get_track_by_id(video_id)
      else
        nil
      end
    else
      handle_error(response)
      nil
    end
  end

  def get_track_url(track_id)
    "https://music.youtube.com/watch?v=#{track_id}"
  end

  private

  def configure(*args)
    # No additional configuration needed beyond the API key
    # which will be pulled from the environment
  end

  def parse_track_url(url)
    return nil unless url.present?

    # Standard YouTube Music URL format:
    # https://music.youtube.com/watch?v={video_id}
    music_match = url.to_s.match(%r{music\.youtube\.com/watch\?v=([a-zA-Z0-9_-]+)})
    return music_match[1] if music_match

    # Standard YouTube URL format that might be a music video:
    # https://www.youtube.com/watch?v={video_id}
    youtube_match = url.to_s.match(%r{youtube\.com/watch\?v=([a-zA-Z0-9_-]+)})
    return youtube_match[1] if youtube_match

    # YouTube Short URL format:
    # https://youtu.be/{video_id}
    short_match = url.to_s.match(%r{youtu\.be/([a-zA-Z0-9_-]+)})
    return short_match[1] if short_match

    nil
  end

  def parse_track_data(data)
    return nil unless data.present?

    snippet = data["snippet"]
    content_details = data["contentDetails"]

    # Try to extract artist and title from the video title
    title_parts = extract_artist_and_title(snippet["title"])

    {
      isrc: nil, # YouTube API doesn't provide ISRC codes directly
      title: title_parts[:title] || snippet["title"],
      artist: title_parts[:artist] || snippet["channelTitle"],
      album: nil, # YouTube API doesn't provide album information
      duration: parse_duration(content_details["duration"]),
      release_year: snippet["publishedAt"].to_s[0..3].to_i,
      platform_id: data["id"],
      url: get_track_url(data["id"]),
      platform: PLATFORM
    }
  end

  def extract_artist_and_title(full_title)
    result = {}

    # Common patterns in music video titles:
    # "Artist - Title"
    # "Artist - Title (Official Video)"
    # "Artist - Title (Official Audio)"
    # "Artist - Title (Lyrics)"
    # "Artist - Title (Official Music Video)"

    # Try to match the most common pattern: "Artist - Title"
    if full_title =~ /(.+)\s+-\s+(.+)/
      artist_part = $1.strip
      title_part = $2.strip

      # Further clean up the title part by removing common suffixes
      title_part = title_part.gsub(/\s*\(Official\s+(?:Video|Audio|Music\s+Video|Lyric\s+Video|Visualizer)\)$/i, "")
      title_part = title_part.gsub(/\s*\(Lyrics\)$/i, "")
      title_part = title_part.gsub(/\s*\(Official\)$/i, "")
      title_part = title_part.gsub(/\s*\[Official\s+(?:Video|Audio|Music\s+Video)\]$/i, "")

      result[:artist] = artist_part
      result[:title] = title_part
    end

    result
  end

  def parse_duration(iso8601_duration)
    # Parse ISO 8601 duration format (e.g., PT4M13S)
    # Returns duration in seconds
    return nil unless iso8601_duration.present?

    # Extract minutes and seconds
    minutes = iso8601_duration.match(/(\d+)M/)&.captures&.first.to_i || 0
    seconds = iso8601_duration.match(/(\d+)S/)&.captures&.first.to_i || 0
    hours = iso8601_duration.match(/(\d+)H/)&.captures&.first.to_i || 0

    # Calculate total seconds
    (hours * 3600) + (minutes * 60) + seconds
  end

  def find_best_match(items, artist, title)
    return items[0] if items.size == 1

    # Convert to lowercase for comparison
    artist_lower = artist.downcase
    title_lower = title.downcase

    # Score each item based on how well it matches the artist and title
    scored_items = items.map do |item|
      snippet = item["snippet"]
      full_title = snippet["title"].downcase
      channel_title = snippet["channelTitle"].downcase

      # Extract parts from the video title
      parts = extract_artist_and_title(snippet["title"])

      # Calculate match scores
      title_score = if parts[:title]&.downcase&.include?(title_lower)
        3
      elsif full_title.include?(title_lower)
        2
      else
        0
      end

      artist_score = if parts[:artist]&.downcase&.include?(artist_lower)
        3
      elsif channel_title.include?(artist_lower)
        2
      elsif full_title.include?(artist_lower)
        1
      else
        0
      end

      # Higher is better
      total_score = title_score + artist_score

      [ item, total_score ]
    end

    # Sort by score (descending) and return the best match
    scored_items.sort_by { |_, score| -score }.first[0]
  end

  def handle_error(response)
    error_message = if response.parsed_response.is_a?(Hash) && response.parsed_response["error"]
      if response.parsed_response["error"].is_a?(Hash)
        "#{response.parsed_response['error']['code']} - #{response.parsed_response['error']['message']}"
      else
        response.parsed_response["error"]
      end
    else
      response.message
    end

    Rails.logger.error "YouTube Music API Error: #{response.code} #{error_message}"
    Rails.logger.error "Response body: #{response.body}" if response.body.present?
  end
end
