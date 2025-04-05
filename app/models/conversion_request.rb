class ConversionRequest < ApplicationRecord
  validates :source_platform, :source_url, presence: true

  PLATFORMS = %w[spotify deezer youtube_music].freeze
  validates :source_platform, inclusion: { in: PLATFORMS }

  before_validation :set_default_platform

  private

  def set_default_platform
    self.source_platform ||= "spotify"
  end

  scope :successful, -> { where(successful: true) }
  scope :failed, -> { where(successful: false) }
end
