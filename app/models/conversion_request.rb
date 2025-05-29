class ConversionRequest < ApplicationRecord
  PLATFORMS = PlatformTrack::PLATFORMS

  validates :source_platform, presence: true, inclusion: { in: PLATFORMS }
  validates :source_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }

  before_validation :set_default_platform

  private

  def set_default_platform
    self.source_platform ||= "spotify"
  end
end
