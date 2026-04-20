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

    db_track = find_existing_track(url, source_platform)
    if db_track
      conversion_request.update!(successful: true)
      return build_response(db_track_to_payload(db_track))
    end

    track_info = fetch_track_info(source_platform, url)

    db_track = find_track_by_isrc(track_info, source_platform, url)
    if db_track
      conversion_request.update!(successful: true)
      return build_response(db_track_to_payload(db_track))
    end

    links = collect_platform_links(track_info)
    conversion_request.update!(successful: true)

    enqueue_track_persistence(track_info, links)

    build_response(track_info_to_payload(track_info, links))
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
        update_track_with_missing_platform(track, platform, url)
      end
    end
  end

  def collect_platform_links(track_info)
    links = { track_info[:platform] => track_info[:url] }

    Rails.logger.debug "Searching track links in other platforms"
    other_platforms = PLATFORM_SERVICES.keys - [ track_info[:platform] ]

    other_platforms.each do |platform|
      service = @services[platform]
      found_track = search_track_on_platform_safely(service, platform, track_info)
      links[platform] = found_track[:url] if found_track
    end

    Rails.logger.debug "Found track links: #{links.keys}"
    links
  end

  def search_track_on_platform_safely(service, platform, track_info)
    search_track_on_platform(service, track_info)
  rescue StandardError => e
    Rails.logger.warn "Search failed on #{platform}: #{e.class} - #{e.message}"
    nil
  end

  def search_track_on_platform(service, track_info)
    if track_info[:isrc].present?
      found_track = service.search_track_by_isrc(track_info[:isrc])
      return found_track if found_track
    end

    if track_info[:artist].present? && track_info[:title].present?
      service.search_track(track_info[:artist], track_info[:title])
    end
  end

  def enqueue_track_persistence(track_info, links)
    return if track_info[:isrc].blank?

    Rails.logger.debug "Track has ISRC, enqueueing PersistTrackJob"
    PersistTrackJob.perform_later(
      track_info.deep_stringify_keys,
      links.transform_keys(&:to_s)
    )
  rescue StandardError => e
    Rails.logger.error "Failed to enqueue PersistTrackJob: #{e.class} - #{e.message}"
  end

  def find_track_in_database(url, platform)
    platform_id = extract_platform_id_from_url(platform, url)
    return nil unless platform_id

    platform_track = PlatformTrack.find_by(platform: platform, platform_id: platform_id)
    platform_track&.track
  end

  def db_track_to_payload(track)
    links = track.platform_tracks.each_with_object({}) do |pt, acc|
      acc[pt.platform.to_s] = pt.url
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

  def track_info_to_payload(track_info, links)
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

  def build_response(payload)
    payload
  end

  def update_track_with_missing_platform(track, platform, url)
    platform_id = extract_platform_id_from_url(platform, url)
    return unless platform_id

    platform_track = track.platform_tracks.find_or_initialize_by(platform: platform.to_s)
    return unless platform_track.new_record?

    platform_track.update!(platform_id: platform_id, url: url)
    Rails.logger.debug "Added missing platform link: #{platform}"
  rescue StandardError => e
    Rails.logger.error "Error saving missing platform link: #{e.class} - #{e.message}"
  end

  def detect_platform(url)
    PLATFORM_DOMAINS.each do |platform, domains|
      return platform if domains.any? { |domain| url.to_s.include?(domain) }
    end
    nil
  end

  def extract_platform_id_from_url(platform, url)
    service = @services[platform.to_sym]
    return nil unless service

    service.parse_track_url(url)
  rescue StandardError => e
    Rails.logger.warn "Failed to extract platform_id for #{platform}: #{e.class} - #{e.message}"
    nil
  end
end
