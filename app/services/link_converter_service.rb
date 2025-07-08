class LinkConverterService
  include MusicPlatforms

  class Error < StandardError; end

  attr_reader :services

  def initialize
    @services = {}
    PLATFORM_SERVICES.each do |platform, service_class|
      @services[platform] = service_class.new
    end
  end

  def convert_url(url)
    Rails.logger.debug "Starting conversion for URL: #{url}"

    source_platform = validate_and_detect_platform(url)
    conversion_request = create_conversion_request(source_platform, url)

    # Try database first
    db_track = find_existing_track(url, source_platform)
    if db_track
      conversion_request.update!(successful: true)
      return build_response_from_database(db_track)
    end

    # Fetch from external service
    track_info = fetch_track_info(source_platform, url)

    # Check database by ISRC
    db_track = find_track_by_isrc(track_info, source_platform, url)
    if db_track
      conversion_request.update!(successful: true)
      return build_response_from_database(db_track)
    end


    # Search other platforms
    links = collect_platform_links(track_info)

    conversion_request.update!(successful: true)
    result = build_response_from_api_data(track_info, links)

    # Save to database if has ISRC
    save_track_if_valid(track_info, links)

    result
  rescue StandardError => e
    Rails.logger.error "Link conversion error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise Error, "Failed to convert link: #{e.message}"
  end

  private

  def validate_and_detect_platform(url)
    source_platform = detect_platform(url)
    raise Error, "Unsupported URL format: #{url}" unless source_platform
    Rails.logger.debug "Detected platform: #{source_platform}"
    source_platform
  end

  def create_conversion_request(platform, url)
    ConversionRequest.create!(source_platform: platform, source_url: url).tap do |request|
      Rails.logger.debug "Created conversion request: #{request.id}"
    end
  end

  def find_existing_track(url, platform)
    find_track_in_database(url, platform).tap do |track|
      Rails.logger.debug "Found track in database: #{track.id}" if track
    end
  end

  def fetch_track_info(platform, url)
    Rails.logger.debug "Track not found in database, fetching from external services"
    source_service = @services[platform]
    Rails.logger.debug "Using service for #{platform}: #{source_service.class}"

    track_info = source_service.get_track_from_url(url)
    Rails.logger.debug "Got track info: #{track_info.inspect}"
    raise Error, "Track info is nil" if track_info.nil?
    track_info
  rescue => e
    Rails.logger.error "Error getting track from URL: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  def find_track_by_isrc(track_info, platform, url)
    return nil unless track_info[:isrc].present?

    Track.find_by(isrc: track_info[:isrc]).tap do |track|
      if track
        Rails.logger.debug "Found track by ISRC in database: #{track.id}"
        update_track_with_missing_platform(track, platform, url, track_info)
      end
    end
  end

  def collect_platform_links(track_info)
    links = { track_info[:platform] => track_info[:url] }

    Rails.logger.debug "Searching track links in other platforms"
    search_other_platforms(track_info, links)
    Rails.logger.debug "Found track links: #{links.keys}"

    links
  rescue => e
    Rails.logger.error "Error finding track links: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    links # Continue anyway - we can still return the original link
  end

  def search_other_platforms(track_info, links)
    other_platforms = PLATFORM_SERVICES.keys - [ track_info[:platform] ]

    other_platforms.each do |platform|
      service = @services[platform]
      found_track = search_track_on_platform(service, track_info)
      links[platform] = found_track[:url] if found_track
    end
  end

  def search_track_on_platform(service, track_info)
    # Try ISRC search first if available
    if track_info[:isrc].present?
      found_track = service.search_track_by_isrc(track_info[:isrc])
      return found_track if found_track
    end

    # Fallback to title/artist search
    if track_info[:artist].present? && track_info[:title].present?
      service.search_track(track_info[:artist], track_info[:title])
    end
  end

  def save_track_if_valid(track_info, links)
    if track_info[:isrc].present?
      Rails.logger.debug "Track has ISRC, saving to database in background"
      save_track_to_database(track_info, links)
    else
      Rails.logger.debug "Track has no ISRC, skipping database save"
    end
  end

  def find_track_in_database(url, platform)
    platform_id = extract_platform_id_from_url(platform, url)
    return nil unless platform_id

    platform_track = PlatformTrack.find_by(platform: platform, platform_id: platform_id)
    platform_track&.track
  end

  def build_response_from_database(track)
    links = {}
    track.platform_tracks.each do |pt|
      links[pt.platform] = pt.url
    end

    {
      track: {
        title: track.title,
        artist: track.artist,
        album: track.album,
        isrc: track.isrc
      },
      links: links
    }
  end

  def update_track_with_missing_platform(track, platform, url, track_info)
    platform_id = extract_platform_id_from_url(platform, url)
    return unless platform_id

    platform_track = track.platform_tracks.find_or_initialize_by(platform: platform)
    if platform_track.new_record?
      platform_track.update!(
        platform_id: platform_id,
        url: url
      )
      Rails.logger.debug "Added missing platform link: #{platform}"
    end
  rescue => e
    Rails.logger.error "Error saving missing platform link: #{e.class} - #{e.message}"
  end

  def detect_platform(url)
    PLATFORM_DOMAINS.each do |platform, domains|
      return platform if domains.any? { |domain| url.to_s.include?(domain) }
    end
    nil
  end


  def build_response_from_api_data(track_info, links)
    {
      track: {
        title: track_info[:title],
        artist: track_info[:artist],
        album: track_info[:album],
        isrc: track_info[:isrc]
      },
      links: links.transform_keys(&:to_s)
    }
  end


  def save_track_to_database(track_info, links)
    begin
      # Find or create track
      track = Track.find_by(isrc: track_info[:isrc])

      if track.nil?
        track = Track.create!(
          isrc: track_info[:isrc],
          title: track_info[:title],
          artist: track_info[:artist],
          album: track_info[:album],
          duration: track_info[:duration],
          release_year: track_info[:release_year]
        )
        Rails.logger.debug "Created new track: #{track.id}"
      else
        Rails.logger.debug "Found existing track: #{track.id}"
      end

      # Save platform tracks
      links.each do |platform, url|
        platform_id = extract_platform_id_from_url(platform.to_sym, url)
        next unless platform_id

        platform_track = track.platform_tracks.find_or_initialize_by(platform: platform)
        platform_track.update!(
          platform_id: platform_id,
          url: url
        )
        Rails.logger.debug "Saved platform track: #{platform}"
      end

    rescue => e
      Rails.logger.error "Error saving track to database: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't re-raise - this is background operation
    end
  end

  def extract_platform_id_from_url(platform, url)
    case platform
    when :spotify
      url.match(/track\/([a-zA-Z0-9]+)/)[1] if url.match(/track\/([a-zA-Z0-9]+)/)
    when :deezer
      url.match(/track\/(\d+)/)[1] if url.match(/track\/(\d+)/)
    when :youtube_music
      url.match(/[?&]v=([^&]+)/)[1] if url.match(/[?&]v=([^&]+)/)
    end
  rescue
    nil
  end
end
