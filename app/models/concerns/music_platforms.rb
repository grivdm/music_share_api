module MusicPlatforms
  SPOTIFY = "spotify".freeze
  DEEZER = "deezer".freeze
  YOUTUBE_MUSIC = "youtube_music".freeze

  PLATFORMS = [ SPOTIFY, DEEZER, YOUTUBE_MUSIC ].freeze

  PLATFORM_SYMBOLS = PLATFORMS.map(&:to_sym).freeze

  PLATFORM_SERVICES = {
    spotify: SpotifyService,
    deezer: DeezerService,
    youtube_music: YoutubeMusicService
  }.freeze

  PLATFORM_DOMAINS = {
    spotify: [ "spotify.com" ],
    deezer: [ "deezer.com", "dzr.page.link", "link.deezer.com" ],
    youtube_music: [ "youtube.com", "youtu.be" ]
  }.freeze
end
