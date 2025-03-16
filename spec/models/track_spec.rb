require 'rails_helper'

RSpec.describe Track, type: :model do
  it "has a valid factory" do
    expect(build(:track)).to be_valid
  end

  describe "validations" do
    it { should validate_presence_of(:isrc) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:artist) }

    describe "uniqueness" do
      subject { create(:track) }
      it { should validate_uniqueness_of(:isrc) }
    end
  end

  describe "associations" do
    it { should have_many(:platform_tracks).dependent(:destroy) }
  end

  describe "#available_platforms" do
    let(:track) { create(:track) }

    before do
      create(:platform_track, :spotify, track: track)
      create(:platform_track, :deezer, track: track)
    end

    it "returns all platforms where track is available" do
      expect(track.available_platforms).to match_array([ 'spotify', 'deezer' ])
    end
  end

  describe "#get_url" do
    let(:track) { create(:track) }
    let!(:spotify_track) { create(:platform_track, :spotify, track: track) }

    it "returns url for the specified platform" do
      expect(track.get_url("spotify")).to eq(spotify_track.url)
    end

    it "returns nil for unavailable platform" do
      expect(track.get_url("apple_music")).to be_nil
    end
  end
end
