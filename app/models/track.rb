class Track < ApplicationRecord
  has_many :platform_tracks, dependent: :destroy

  validates :isrc, uniqueness: true, allow_blank: true,
            format: { with: /\A[A-Z]{2}[A-Z0-9]{3}\d{7}\z/, message: "must be a valid ISRC format" },
            if: :isrc?
  validates :title, :artist, presence: true
  validates :duration, numericality: { greater_than: 0 }, allow_nil: true
  validates :release_year, numericality: {
    greater_than: 1900,
    less_than_or_equal_to: -> { Date.current.year + 1 }
  }, allow_nil: true


  def available_platforms
    platform_tracks.pluck(:platform)
  end

  def get_url(platform)
    platform_tracks.find_by(platform: platform)&.url
  end

  def platform_track_for(platform)
    platform_tracks.find_by(platform: platform)
  end
end
