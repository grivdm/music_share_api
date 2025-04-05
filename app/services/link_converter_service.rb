class LinkConverterService
  class Error < StandardError; end

  PLATFORM_SERVICES = {
    spotify: SpotifyService,
    deezer: DeezerService,
    youtube_music: YoutubeMusicService
  }.freeze

  attr_reader :services

  def initialize
    @services = {}
    PLATFORM_SERVICES.each do |platform, service_class|
      @services[platform] = service_class.new
    end
  end

  def convert_url(url)
    begin

      Rails.logger.debug "Starting conversion for URL: #{url}"
      source_platform = detect_platform(url)
      Rails.logger.debug "Detected platform: #{source_platform}"
      unless source_platform
        raise Error, "Unsupported URL format: #{url}"
      end


      conversion_request = ConversionRequest.create!(
        source_platform: source_platform,
        source_url: url
      )
      Rails.logger.debug "Created conversion request: #{conversion_request.id}"


      source_service = @services[source_platform]
      Rails.logger.debug "Using service for #{source_platform}: #{source_service.class}"

      begin
        track_info = source_service.get_track_from_url(url)
        Rails.logger.debug "Got track info: #{track_info.inspect}"
      rescue => e
        Rails.logger.error "Error getting track from URL: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        raise
      end


      track = find_or_create_track(track_info)
      Rails.logger.debug "Found/created track: #{track.id}"


      update_platform_track(track, track_info)
      Rails.logger.debug "Updated platform track"


      Rails.logger.debug "Finding track links in other platforms"
      begin
        find_track_links(track, track_info)
        Rails.logger.debug "Found track links"
      rescue => e
        Rails.logger.error "Error finding track links: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        raise
      end


      conversion_request.update!(successful: true)
      Rails.logger.debug "Updated conversion request status"


      format_result(track)
    rescue StandardError => e
      Rails.logger.error "Link conversion error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise Error, "Failed to convert link: #{e.message}"
    end
  end

  private

  def detect_platform(url)
    if url.to_s.include?("spotify.com")
      :spotify
    elsif url.to_s.include?("deezer.com") || url.to_s.include?("dzr.page.link")
      :deezer
    elsif url.to_s.include?("youtube.com") || url.to_s.include?("youtu.be")
      :youtube_music
    else
      nil
    end
  end

  def find_or_create_track(track_info)
    # Safety check for nil track_info
    if track_info.nil?
      Rails.logger.error "Track info is nil in find_or_create_track"
      raise Error, "Failed to retrieve track information"
    end

    # Safety checks for required fields
    unless track_info[:title].present? && track_info[:artist].present?
      Rails.logger.error "Missing required track info fields: #{track_info.inspect}"
      raise Error, "Missing required track information (title and artist)"
    end

    track = Track.find_by(isrc: track_info[:isrc]) if track_info[:isrc].present?

    if track.nil?
      track = Track.find_by(
        artist: track_info[:artist],
        title: track_info[:title]
      )
    end

    if track.nil?
      track = Track.create!(
        isrc: track_info[:isrc],
        title: track_info[:title],
        artist: track_info[:artist],
        album: track_info[:album],
        duration: track_info[:duration],
        release_year: track_info[:release_year]
      )
    end

    track
  end

  def update_platform_track(track, track_info)
    platform_track = track.platform_tracks.find_or_initialize_by(
      platform: track_info[:platform]
    )

    platform_track.update!(
      platform_id: track_info[:platform_id],
      url: track_info[:url]
    )
  end

  def find_track_links(track, track_info)
    (PLATFORM_SERVICES.keys - [ track_info[:platform] ]).each do |platform|
      next if track.platform_tracks.exists?(platform: platform)


      service = @services[platform]


      found_track = nil
      if track_info[:isrc].present?
        found_track = service.search_track_by_isrc(track_info[:isrc])
      end


      if found_track.nil? && track_info[:artist].present? && track_info[:title].present?
        found_track = service.search_track(track_info[:artist], track_info[:title])
      end


      if found_track
        track.platform_tracks.create!(
          platform: platform,
          platform_id: found_track[:platform_id],
          url: found_track[:url]
        )
      end
    end
  end

  def format_result(track)
    result = {
      track: {
        title: track.title,
        artist: track.artist,
        album: track.album,
        isrc: track.isrc
      },
      links: {}
    }

    track.platform_tracks.each do |platform_track|
      result[:links][platform_track.platform] = platform_track.url
    end

    result
  end
end
