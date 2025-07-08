require 'rails_helper'

RSpec.describe Track, type: :model do
  subject(:track) { build(:track) }
  it "has a valid factory" do
    expect(track).to be_valid
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:artist) }
    it { should validate_numericality_of(:duration).is_greater_than(0).allow_nil }
    it { should validate_numericality_of(:release_year).is_greater_than(1900).allow_nil }

    describe "ISRC validation" do
      subject { create(:track) }

      it { should validate_uniqueness_of(:isrc).allow_blank }

      it "validates ISRC format" do
        track.isrc = "INVALID"
        expect(track).not_to be_valid
        expect(track.errors[:isrc]).to include("must be a valid ISRC format")
      end

      it "allows valid ISRC format" do
        track.isrc = "USRC12345678"
        expect(track).to be_valid
      end

      it "allows blank ISRC" do
        track.isrc = nil
        expect(track).to be_valid
      end
    end

    describe "release year validation" do
      it "validates release year is not too far in future" do
        track.release_year = Date.current.year + 2
        expect(track).not_to be_valid
      end

      it "allows current year" do
        track.release_year = Date.current.year
        expect(track).to be_valid
      end
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

  describe "#platform_track_for" do
    let(:track) { create(:track) }
    let!(:spotify_track) { create(:platform_track, :spotify, track: track) }

    it "returns platform track for the specified platform" do
      expect(track.platform_track_for("spotify")).to eq(spotify_track)
    end

    it "returns nil for unavailable platform" do
      expect(track.platform_track_for("apple_music")).to be_nil
    end
  end
end
