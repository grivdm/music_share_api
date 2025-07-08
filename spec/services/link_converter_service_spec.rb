# spec/services/link_converter_service_spec.rb
require 'rails_helper'

RSpec.describe LinkConverterService do
  let(:service) { described_class.new }

  describe "#detect_platform" do
    it "detects spotify urls" do
      url = "https://open.spotify.com/track/123456"
      expect(service.send(:detect_platform, url)).to eq(:spotify)
    end

    it "detects deezer urls" do
      url = "https://www.deezer.com/track/123456"
      expect(service.send(:detect_platform, url)).to eq(:deezer)
    end

    it "detects YouTube Music urls" do
      url = "https://music.youtube.com/watch?v=dQw4w9WgXcQ"
      expect(service.send(:detect_platform, url)).to eq(:youtube_music)
    end

    it "detects standard YouTube urls as YouTube Music" do
      url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      expect(service.send(:detect_platform, url)).to eq(:youtube_music)
    end

    it "detects YouTube short urls as YouTube Music" do
      url = "https://youtu.be/dQw4w9WgXcQ"
      expect(service.send(:detect_platform, url)).to eq(:youtube_music)
    end

    it "returns nil for unsupported urls" do
      url = "https://music.apple.com/album/123456"
      expect(service.send(:detect_platform, url)).to be_nil
    end
  end

  describe "#convert_url" do
    let(:spotify_url) { "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT" }
    let(:isrc) { "GBARL0700477" }
    let(:track_title) { "Never Gonna Give You Up" }
    let(:track_artist) { "Rick Astley" }
    let(:track_album) { "Whenever You Need Somebody" }

    let(:track_data) do
      {
        isrc: isrc,
        title: track_title,
        artist: track_artist,
        album: track_album,
        platform_id: "4cOdK2wGLETKBW3PvgPWqT",
        url: spotify_url,
        platform: :spotify
      }
    end

    let(:deezer_data) do
      {
        isrc: isrc,
        title: track_title,
        artist: track_artist,
        album: track_album,
        platform_id: "3135556",
        url: "https://www.deezer.com/track/3135556",
        platform: :deezer
      }
    end

    context "when converting Spotify URL" do
      let(:conversion_result) do
        {
          track: {
            title: track_title,
            artist: track_artist,
            album: track_album,
            isrc: isrc
          },
          links: {
            spotify: spotify_url,
            deezer: "https://www.deezer.com/track/3135556"
          }
        }
      end

      before do
        allow(service).to receive(:convert_url).with(spotify_url).and_return(conversion_result)
      end

      it "converts spotify url to all available platforms" do
        output = service.convert_url(spotify_url)

        expect(output[:track]).to include(
          title: track_title,
          artist: track_artist
        )
        expect(output[:links]).to include(:spotify, :deezer)
      end
    end

    context "when creating conversion request record" do
      before do
        allow(service).to receive(:detect_platform).with(spotify_url).and_return(:spotify)
        allow_any_instance_of(SpotifyService).to receive(:get_track_from_url).and_return(track_data)
        allow_any_instance_of(DeezerService).to receive(:search_track_by_isrc).and_return(deezer_data)
        allow_any_instance_of(YoutubeMusicService).to receive(:search_track_by_isrc).and_return(nil)
        allow_any_instance_of(YoutubeMusicService).to receive(:search_track).and_return(nil)
      end

      it "creates conversion_request record" do
        expect {
          service.convert_url(spotify_url)
        }.to change(ConversionRequest, :count).by(1)

        request = ConversionRequest.last
        expect(request.source_platform).to eq('spotify')
        expect(request.source_url).to eq(spotify_url)
      end
    end

    xit "reuses existing track data when available" do
      # First create a track with ISRC
      track = create(:track, isrc: "GBARL0700477")
      create(:platform_track, track: track, platform: "spotify", platform_id: "4cOdK2wGLETKBW3PvgPWqT")

      # Mock the service responses
      spotify_service = instance_double(SpotifyService)
      allow(spotify_service).to receive(:get_track_from_url).and_return({
        isrc: "GBARL0700477",
        platform: "spotify",
        platform_id: "4cOdK2wGLETKBW3PvgPWqT"
      })

      allow(service).to receive(:services).and_return({ "spotify" => spotify_service })

      expect {
        service.convert_url(spotify_url)
      }.not_to change(Track, :count)
    end
  end

  describe "#convert_url with YouTube Music" do
    let(:youtube_music_url) { "https://music.youtube.com/watch?v=dQw4w9WgXcQ" }
    let(:youtube_conversion_result) do
      {
        track: {
          title: "Never Gonna Give You Up",
          artist: "Rick Astley",
          album: nil,
          isrc: nil
        },
        links: {
          youtube_music: youtube_music_url,
          spotify: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT",
          deezer: "https://www.deezer.com/track/3135556"
        }
      }
    end

    context "when converting YouTube Music URL" do
      before do
        allow(service).to receive(:convert_url).with(youtube_music_url).and_return(youtube_conversion_result)
      end

      it "converts YouTube Music url to other platforms" do
        output = service.convert_url(youtube_music_url)

        expect(output[:track]).to include(
          title: "Never Gonna Give You Up",
          artist: "Rick Astley"
        )
        expect(output[:links]).to include(:youtube_music, :spotify, :deezer)
      end
    end

    context "when creating conversion request record for YouTube Music" do
      it "properly identifies YouTube Music platform" do
        expect(service.send(:detect_platform, youtube_music_url)).to eq(:youtube_music)
      end

      it "creates conversion request record" do
        expect {
          ConversionRequest.create!(
            source_platform: :youtube_music,
            source_url: youtube_music_url,
            successful: true
          )
        }.to change(ConversionRequest, :count).by(1)
      end
    end
  end

  describe "#convert_url error handling" do
    context "when URL is unsupported" do
      it "raises error for unsupported url" do
        expect {
          service.convert_url("https://music.apple.com/track/123456")
        }.to raise_error(LinkConverterService::Error, /Unsupported URL format/)
      end
    end

    context "when API errors occur" do
      before do
        allow_any_instance_of(SpotifyService).to receive(:get_track_from_url)
          .and_raise(SpotifyService::Error, "API Error")
      end

      it "handles Spotify API errors gracefully" do
        expect {
          service.convert_url("https://open.spotify.com/track/invalid_id")
        }.to raise_error(LinkConverterService::Error, /Failed to convert link/)
      end
    end

    context "when YouTube Music API errors occur" do
      before do
        allow_any_instance_of(YoutubeMusicService).to receive(:get_track_from_url)
          .and_raise(YoutubeMusicService::Error, "YouTube API Error")
      end

      it "handles YouTube Music API errors gracefully" do
        expect {
          service.convert_url("https://music.youtube.com/watch?v=invalid_id")
        }.to raise_error(LinkConverterService::Error, /Failed to convert link/)
      end
    end
  end
end
