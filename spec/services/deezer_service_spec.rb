require 'rails_helper'

RSpec.describe DeezerService do
  let(:service) { DeezerService.new }

  describe "#parse_track_url" do
    it "extracts track id from standard deezer url" do
      url = "https://www.deezer.com/track/3135556"
      expect(service.send(:parse_track_url, url)).to eq("3135556")
    end

    it "extracts track id from localized deezer url" do
      url = "https://www.deezer.com/en/track/3135556"
      expect(service.send(:parse_track_url, url)).to eq("3135556")
    end

    it "returns nil for invalid url" do
      url = "https://www.deezer.com/album/12345"
      expect(service.send(:parse_track_url, url)).to be_nil
    end
  end

  describe "#get_track_by_id", vcr: { cassette_name: 'deezer/get_track' } do
    it "fetches track information from Deezer API" do
      track_info = service.get_track_by_id("3135556")

      expect(track_info).to include(
        platform: :deezer,
        title: "Harder, Better, Faster, Stronger",
        artist: "Daft Punk"
      )
      expect(track_info[:platform_id]).to eq("3135556")
      expect(track_info[:url]).to include("deezer.com/track")
    end
  end

  describe "#search_track", vcr: { cassette_name: 'deezer/search_track' } do
    it "finds a track by artist and title" do
      track_info = service.search_track("Daft Punk", "Harder Better Faster Stronger")

      expect(track_info).to include(
        platform: :deezer,
        artist: "Daft Punk"
      )
      expect(track_info[:title]).to match(/Harder.+Better.+Faster.+Stronger/)
    end
  end
end
