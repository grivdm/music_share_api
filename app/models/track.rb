class Track < ApplicationRecord
  has_many :platform_tracks, dependent: :destroy

  validates :isrc, presence: true, uniqueness: true
  validates :title, :artist, presence: true


  def available_platforms
    platform_tracks.pluck(:platform).map(&:to_s)
  end

  def get_url(platform)
    platform_tracks.find_by(platform: platform)&.url
  end
end
