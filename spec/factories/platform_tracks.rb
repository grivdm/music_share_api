FactoryBot.define do
  factory :platform_track do
    association :track
    platform { "spotify" }
    platform_id { "spotify_track_id" }
    url { "https://open.spotify.com/track/spotify_track_id" }

    trait :spotify do
      platform { "spotify" }
      platform_id { "spotify_track_id" }
      url { "https://open.spotify.com/track/spotify_track_id" }
    end

    trait :deezer do
      platform { "deezer" }
      platform_id { "123456789" }
      url { "https://www.deezer.com/track/123456789" }
    end

    trait :youtube_music do
      platform { "youtube_music" }
      platform_id { "dQw4w9WgXcQ" }
      url { "https://music.youtube.com/watch?v=dQw4w9WgXcQ" }
    end
  end
end
