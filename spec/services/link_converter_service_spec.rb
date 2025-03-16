# spec/services/link_converter_service_spec.rb
require 'rails_helper'

RSpec.describe LinkConverterService do
  let(:service) { LinkConverterService.new }

  describe "#detect_platform" do
    it "detects spotify urls" do
      url = "https://open.spotify.com/track/123456"
      expect(service.send(:detect_platform, url)).to eq(:spotify)
    end

    it "detects deezer urls" do
      url = "https://www.deezer.com/track/123456"
      expect(service.send(:detect_platform, url)).to eq(:deezer)
    end

    it "returns nil for unsupported urls" do
      url = "https://music.apple.com/album/123456"
      expect(service.send(:detect_platform, url)).to be_nil
    end
  end

  describe "#convert_url", vcr: { cassette_name: 'link_converter/convert_spotify_to_deezer' } do
    let(:spotify_url) { "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT" }

    it "converts spotify url to all available platforms" do
      result = service.convert_url(spotify_url)

      expect(result[:track]).to include(
        title: "Never Gonna Give You Up",
        artist: "Rick Astley"
      )
      expect(result[:links]).to have_key('spotify')
      expect(result[:links]).to have_key('deezer')
    end

    it "creates conversion_request record" do
      expect {
        service.convert_url(spotify_url)
      }.to change(ConversionRequest, :count).by(1)

      request = ConversionRequest.last
      expect(request.source_platform).to eq('spotify')
      expect(request.source_url).to eq(spotify_url)
      expect(request.successful).to be true
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

  describe "#convert_url with error handling" do
    it "raises error for unsupported url" do
      expect {
        service.convert_url("https://music.apple.com/track/123456")
      }.to raise_error(LinkConverterService::Error, /Unsupported URL format/)
    end

    it "handles API errors gracefully", vcr: { cassette_name: 'link_converter/handle_api_error' } do
      allow_any_instance_of(SpotifyService).to receive(:get_track_from_url).and_raise(SpotifyService::Error, "API Error")

      expect {
        service.convert_url("https://open.spotify.com/track/invalid_id")
      }.to raise_error(LinkConverterService::Error, /Failed to convert link/)
    end
  end
end
