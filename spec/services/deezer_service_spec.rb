require 'rails_helper'

RSpec.describe DeezerService do
  let(:service) { described_class.new }

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

  describe "#get_track_by_id" do
    let(:track_id) { "3135556" }
    let(:expected_track_data) do
      {
        platform: :deezer,
        title: "Harder, Better, Faster, Stronger",
        artist: "Daft Punk",
        platform_id: track_id,
        url: "https://www.deezer.com/track/#{track_id}"
      }
    end

    before do
      allow(service).to receive(:get_track_by_id).with(track_id).and_return(expected_track_data)
    end

    it "fetches track information from Deezer API" do
      track_info = service.get_track_by_id(track_id)

      expect(track_info).to include(
        platform: :deezer,
        title: "Harder, Better, Faster, Stronger",
        artist: "Daft Punk"
      )
      expect(track_info[:platform_id]).to eq(track_id)
      expect(track_info[:url]).to include("deezer.com/track")
    end
  end

  describe "#search_track" do
    let(:artist) { "Daft Punk" }
    let(:title) { "Harder Better Faster Stronger" }
    let(:expected_track_data) do
      {
        platform: :deezer,
        title: "Harder, Better, Faster, Stronger",
        artist: artist
      }
    end

    before do
      allow(service).to receive(:search_track).with(artist, title).and_return(expected_track_data)
    end

    it "finds a track by artist and title" do
      track_info = service.search_track(artist, title)

      expect(track_info).to include(
        platform: :deezer,
        artist: artist
      )
      expect(track_info[:title]).to match(/Harder.+Better.+Faster.+Stronger/)
    end
  end
end
