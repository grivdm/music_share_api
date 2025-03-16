FactoryBot.define do
  factory :conversion_request do
    source_platform { "spotify" }
    source_url { "https://open.spotify.com/track/spotify_track_id" }
    successful { true }

    trait :failed do
      successful { false }
    end

    trait :from_deezer do
      source_platform { "deezer" }
      source_url { "https://www.deezer.com/track/123456789" }
    end
  end
end
