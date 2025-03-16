class ConversionRequest < ApplicationRecord
  validates :source_platform, :source_url, presence: true

  enum :source_platform, { spotify: "spotify", deezer: "deezer" }, default: "spotify"

  scope :successful, -> { where(successful: true) }
  scope :failed, -> { where(successful: false) }
end
