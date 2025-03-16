class MusicPlatformService
  class Error < StandardError; end

  def initialize(*args)
    configure(*args)
  end

  private

  def configure(*args)
    raise NotImplementedError, "Subclasses must implement #configure"
  end

  def parse_track_url(url)
    raise NotImplementedError, "Subclasses must implement #parse_track_url"
  end

  def get_track_by_id(id)
    raise NotImplementedError, "Subclasses must implement #get_track_by_id"
  end

  def search_track_by_isrc(isrc)
    raise NotImplementedError, "Subclasses must implement #search_track_by_isrc"
  end

  def search_track(artist, title)
    raise NotImplementedError, "Subclasses must implement #search_track"
  end

  def get_track_url(track_id)
    raise NotImplementedError, "Subclasses must implement #get_track_url"
  end
end
