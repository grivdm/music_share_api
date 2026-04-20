class PersistTrackJob < ApplicationJob
  include MusicPlatforms

  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(track_info, links)
    track_info = track_info.deep_symbolize_keys
    return if track_info[:isrc].blank?

    track = Track.find_or_create_by!(isrc: track_info[:isrc]) do |t|
      t.title = track_info[:title]
      t.artist = track_info[:artist]
      t.album = track_info[:album]
      t.duration = track_info[:duration]
      t.release_year = track_info[:release_year]
    end

    links.each do |platform, url|
      next if url.blank?

      platform_sym = platform.to_sym
      service = PLATFORM_SERVICES[platform_sym]&.new
      next unless service

      platform_id = safe_extract_platform_id(service, url)
      next unless platform_id

      platform_track = track.platform_tracks.find_or_initialize_by(platform: platform_sym.to_s)
      platform_track.update!(platform_id: platform_id, url: url)
    end
  end

  private

  def safe_extract_platform_id(service, url)
    service.parse_track_url(url)
  rescue StandardError => e
    Rails.logger.warn "PersistTrackJob: failed to extract platform_id for #{url}: #{e.class} - #{e.message}"
    nil
  end
end
