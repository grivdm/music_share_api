class DeezerService < MusicPlatformService
  include ApiErrorHandling
  BASE_API_URL = "https://api.deezer.com".freeze
  PLATFORM = :deezer

  def get_track_from_url(url)
    track_id = parse_track_url(url)
    return nil unless track_id
    get_track_by_id(track_id)
  end

  def get_track_by_id(id)
    response = HTTParty.get("#{BASE_API_URL}/track/#{id}")

    if response.success?
      parse_track_data(response.parsed_response)
    else
      handle_error(response)
      nil
    end
  end

  def search_track_by_isrc(isrc)
    return nil unless isrc.present?

    response = HTTParty.get(
      "#{BASE_API_URL}/search/track",
      query: { q: "isrc:\"#{isrc}\"" }
    )

    if response.success? && response["data"].present? && response["data"].any?
      parse_track_data(response["data"][0])
    else
      nil
    end
  end

  def search_track(artist, title)
    return nil unless artist.present? && title.present?

    query = "#{artist} #{title}".gsub('"', "")
    response = HTTParty.get(
      "#{BASE_API_URL}/search/track",
      query: { q: query }
    )

    if response.success? && response["data"].present? && response["data"].any?

      best_match = find_best_match(response["data"], artist, title)
      parse_track_data(best_match)
    else
      nil
    end
  end

  def get_track_url(track_id)
    "https://www.deezer.com/track/#{track_id}"
  end

  private

  def configure(*args)
  end

  def parse_track_url(url)
    return nil unless url.present?

    # https://www.deezer.com/track/{id}
    # or https://www.deezer.com/en/track/{id}
    match = url.to_s.match(/deezer\.com\/(?:\w+\/)?track\/(\d+)/)
    return match[1] if match

    # Short URL format: https://dzr.page.link/{random_id} or https://link.deezer.com/s/...
    if url.to_s.include?("dzr.page.link") || url.to_s.include?("link.deezer.com/")
      current_url = url.to_s
      max_redirects = 5
      max_redirects.times do
        response = HTTParty.head(current_url, follow_redirects: false)
        if response.code.between?(300, 399)
          location = response.headers["location"]
          if location.present?
            match = location.match(/deezer\.com\/(?:\w+\/)?track\/(\d+)/)
            return match[1] if match
            current_url = location
          else
            break
          end
        else
          break
        end
      end
    end

    nil
  end

  def parse_track_data(data)
    return nil unless data.present?

    {
      isrc: data["isrc"],
      title: data["title"],
      artist: data.dig("artist", "name"),
      album: data.dig("album", "title"),
      duration: data["duration"],
      release_year: data.dig("album", "release_date")&.split("-")&.first&.to_i,
      platform_id: data["id"].to_s,
      url: data["link"],
      platform: PLATFORM
    }
  end

  def find_best_match(tracks, artist, title)
    return tracks[0] if tracks.size == 1


    artist_lower = artist.downcase
    title_lower = title.downcase


    exact_match = tracks.find do |track|
      track_artist = track.dig("artist", "name").to_s.downcase
      track_title = track["title"].to_s.downcase

      track_artist == artist_lower && track_title == title_lower
    end

    return exact_match if exact_match


    tracks.sort_by do |track|
      track_artist = track.dig("artist", "name").to_s.downcase
      track_title = track["title"].to_s.downcase


      artist_similarity = levenshtein_distance(track_artist, artist_lower)
      title_similarity = levenshtein_distance(track_title, title_lower)

      artist_similarity + title_similarity
    end.first
  end

  def levenshtein_distance(str1, str2)
    Text::Levenshtein.distance(str1, str2)
  end

  def handle_error(response)
    handle_api_error(response, "Deezer")
  end
end
