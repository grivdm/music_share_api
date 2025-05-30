require 'rails_helper'

RSpec.describe SpotifyService do
  let(:service) { described_class.new }

  describe "#parse_track_url" do
    it "extracts track id from standard spotify url" do
      url = "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT"
      expect(service.send(:parse_track_url, url)).to eq("4cOdK2wGLETKBW3PvgPWqT")
    end

    it "extracts track id from spotify url with query parameters" do
      url = "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123def456"
      expect(service.send(:parse_track_url, url)).to eq("4cOdK2wGLETKBW3PvgPWqT")
    end

    it "returns nil for invalid url" do
      url = "https://open.spotify.com/playlist/12345"
      expect(service.send(:parse_track_url, url)).to be_nil
    end
  end

  describe "#get_track_by_id" do
    let(:track_id) { "4cOdK2wGLETKBW3PvgPWqT" }
    let(:expected_track_data) do
      {
        platform: :spotify,
        title: "Never Gonna Give You Up",
        artist: "Rick Astley",
        isrc: "GBARL0700477",
        album: "Whenever You Need Somebody",
        platform_id: track_id,
        url: "https://open.spotify.com/track/#{track_id}"
      }
    end

    before do
      allow(service).to receive(:get_track_by_id).with(track_id).and_return(expected_track_data)
    end

    it "fetches track information from Spotify API" do
      track_info = service.get_track_by_id(track_id)

      expect(track_info).to include(
        platform: :spotify,
        title: "Never Gonna Give You Up",
        artist: "Rick Astley"
      )
      expect(track_info[:isrc]).to eq("GBARL0700477")
      expect(track_info[:url]).to include("spotify.com/track")
    end
  end

  describe "#search_track_by_isrc" do
    let(:isrc) { "GBARL0700477" }
    let(:expected_track_data) do
      {
        title: "Never Gonna Give You Up",
        artist: "Rick Astley",
        isrc: isrc,
        album: "Whenever You Need Somebody",
        platform_id: "4cOdK2wGLETKBW3PvgPWqT",
        url: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT",
        platform: :spotify
      }
    end

    before do
      allow(service).to receive(:search_track_by_isrc).with(isrc).and_return(expected_track_data)
    end

    it "finds a track by ISRC code" do
      track_info = service.search_track_by_isrc(isrc)

      expect(track_info).to include(
        title: "Never Gonna Give You Up",
        artist: "Rick Astley",
        isrc: isrc
      )
    end
  end
end
