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

      # First, search all platforms and collect links
      links = { track_info[:platform] => track_info[:url] }

      Rails.logger.debug "Searching track links in other platforms"
      begin
        # Search other platforms first
        (PLATFORM_SERVICES.keys - [ track_info[:platform] ]).each do |platform|
          service = @services[platform]

          found_track = nil
          # Try ISRC search first if available
          if track_info[:isrc].present?
            found_track = service.search_track_by_isrc(track_info[:isrc])
          end

          # Fallback to title/artist search
          if found_track.nil? && track_info[:artist].present? && track_info[:title].present?
            found_track = service.search_track(track_info[:artist], track_info[:title])
          end

          if found_track
            links[platform] = found_track[:url]
          end
        end
        Rails.logger.debug "Found track links: #{links.keys}"
      rescue => e
        Rails.logger.error "Error finding track links: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # Continue anyway - we can still return the original link
      end

      # Update conversion request as successful
      conversion_request.update!(successful: true)
      Rails.logger.debug "Updated conversion request status"

      # Return result immediately
      result = format_result_without_db(track_info, links)

      # Save to database asynchronously if track has ISRC
      if track_info[:isrc].present?
        Rails.logger.debug "Track has ISRC, saving to database in background"
        save_track_to_database(track_info, links)
      else
        Rails.logger.debug "Track has no ISRC, skipping database save"
      end

      result
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


  def format_result_without_db(track_info, links)
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
