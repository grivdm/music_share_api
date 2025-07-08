class PlatformTrack < ApplicationRecord
  include MusicPlatforms

  belongs_to :track

  validates :platform, presence: true, inclusion: { in: PLATFORMS }, uniqueness: { scope: :track_id }
  validates :platform_id, presence: true, uniqueness: { scope: :platform }
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }

  scope :by_platform, ->(platform) { where(platform: platform) }
end
