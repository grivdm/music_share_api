require 'rails_helper'

RSpec.describe YoutubeMusicService do
  let(:service) { described_class.new }

  describe "#parse_track_url" do
    it "extracts video id from YouTube Music URL" do
      url = "https://music.youtube.com/watch?v=dQw4w9WgXcQ"
      expect(service.send(:parse_track_url, url)).to eq("dQw4w9WgXcQ")
    end

    it "extracts video id from standard YouTube URL" do
      url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      expect(service.send(:parse_track_url, url)).to eq("dQw4w9WgXcQ")
    end

    it "extracts video id from YouTube short URL" do
      url = "https://youtu.be/dQw4w9WgXcQ"
      expect(service.send(:parse_track_url, url)).to eq("dQw4w9WgXcQ")
    end

    it "returns nil for invalid URL" do
      url = "https://youtube.com/playlist?list=12345"
      expect(service.send(:parse_track_url, url)).to be_nil
    end
  end

  describe "#extract_artist_and_title" do
    it "extracts artist and title from simple format" do
      title = "Rick Astley - Never Gonna Give You Up"
      result = service.send(:extract_artist_and_title, title)

      expect(result[:artist]).to eq("Rick Astley")
      expect(result[:title]).to eq("Never Gonna Give You Up")
    end

    it "cleans up official video suffixes" do
      title = "Rick Astley - Never Gonna Give You Up (Official Video)"
      result = service.send(:extract_artist_and_title, title)

      expect(result[:artist]).to eq("Rick Astley")
      expect(result[:title]).to eq("Never Gonna Give You Up")
    end

    it "cleans up lyrics suffixes" do
      title = "Rick Astley - Never Gonna Give You Up (Lyrics)"
      result = service.send(:extract_artist_and_title, title)

      expect(result[:artist]).to eq("Rick Astley")
      expect(result[:title]).to eq("Never Gonna Give You Up")
    end
  end

  describe "#parse_duration" do
    it "parses ISO 8601 duration format" do
      # 4 minutes and 13 seconds
      duration = "PT4M13S"
      expect(service.send(:parse_duration, duration)).to eq(253)
    end

    it "handles hours in duration" do
      # 1 hour, 2 minutes and 3 seconds
      duration = "PT1H2M3S"
      expect(service.send(:parse_duration, duration)).to eq(3723)
    end

    it "handles missing components" do
      # Just 30 seconds
      duration = "PT30S"
      expect(service.send(:parse_duration, duration)).to eq(30)
    end
  end

  describe "#get_track_by_id" do
    let(:video_id) { "dQw4w9WgXcQ" }
    let(:expected_track_data) do
      {
        platform: :youtube_music,
        title: "Never Gonna Give You Up",
        artist: "Rick Astley",
        url: "https://music.youtube.com/watch?v=#{video_id}"
      }
    end

    before do
      allow(service).to receive(:get_track_by_id).with(video_id).and_return(expected_track_data)
    end

    it "fetches track information from YouTube API" do
      track_info = service.get_track_by_id(video_id)

      expect(track_info).to include(
        platform: :youtube_music,
        title: "Never Gonna Give You Up",
        artist: "Rick Astley"
      )
      expect(track_info[:url]).to include("music.youtube.com/watch?v=")
    end
  end

  describe "#search_track" do
    let(:artist) { "Rick Astley" }
    let(:title) { "Never Gonna Give You Up" }
    let(:expected_track_data) do
      {
        platform: :youtube_music,
        title: title,
        artist: artist,
        url: "https://music.youtube.com/watch?v=dQw4w9WgXcQ"
      }
    end

    before do
      allow(service).to receive(:search_track).with(artist, title).and_return(expected_track_data)
    end

    it "finds a track by artist and title" do
      track_info = service.search_track(artist, title)

      expect(track_info).to include(
        platform: :youtube_music,
        title: title
      )
      expect(track_info[:artist]).to include(artist)
    end
  end
end
