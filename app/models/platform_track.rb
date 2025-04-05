class PlatformTrack < ApplicationRecord
  belongs_to :track

  validates :platform, presence: true
  validates :platform_id, presence: true, uniqueness: { scope: :platform }
  validates :url, presence: true
  validates :platform, uniqueness: { scope: :track_id }

  PLATFORMS = %w[spotify deezer youtube_music].freeze
  validates :platform, inclusion: { in: PLATFORMS }
end
