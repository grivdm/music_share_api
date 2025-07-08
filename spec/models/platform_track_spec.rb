require 'rails_helper'

RSpec.describe PlatformTrack, type: :model do
  subject(:platform_track) { build(:platform_track) }
  it "has a valid factory" do
    expect(platform_track).to be_valid
  end

  describe "validations" do
    it { should validate_presence_of(:platform) }
    it { should validate_presence_of(:platform_id) }
    it { should validate_presence_of(:url) }
    it { should validate_inclusion_of(:platform).in_array(MusicPlatforms::PLATFORMS) }

    describe "uniqueness validations" do
      let(:track) { create(:track) }

      context "platform_id uniqueness" do
        it "validates uniqueness of platform_id scoped to platform" do
          create(:platform_track, :spotify)
          duplicate = build(:platform_track, :spotify)

          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:platform_id]).to include("has already been taken")
        end

        it "allows same platform_id on different platforms" do
          spotify_track = create(:platform_track, :spotify)
          different_platform = PlatformTrack.new(
            track: create(:track),
            platform: "deezer",
            platform_id: spotify_track.platform_id,
            url: "https://www.deezer.com/track/123"
          )

          expect(different_platform).to be_valid
        end
      end

      context "platform uniqueness per track" do
        before { create(:platform_track, :spotify, track: track) }

        it "validates uniqueness of platform scoped to track_id" do
          duplicate = build(:platform_track, :spotify, track: track)
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:platform]).to include("has already been taken")
        end

        it "allows same platform on different tracks" do
          different_track = create(:track)
          same_platform = PlatformTrack.new(
            track: different_track,
            platform: "spotify",
            platform_id: "different_spotify_id",
            url: "https://open.spotify.com/track/different_spotify_id"
          )

          expect(same_platform).to be_valid
        end
      end
    end

    describe "URL format validation" do
      it "validates URL format" do
        platform_track.url = "invalid-url"
        expect(platform_track).not_to be_valid
        expect(platform_track.errors[:url]).to include("is invalid")
      end

      it "allows valid URL format" do
        platform_track.url = "https://example.com/track"
        expect(platform_track).to be_valid
      end
    end
  end

  describe "associations" do
    it { should belong_to(:track) }
  end

  describe "scopes" do
    let!(:spotify_track) { create(:platform_track, :spotify) }
    let!(:deezer_track) { create(:platform_track, :deezer) }

    describe ".by_platform" do
      it "returns tracks for specified platform" do
        expect(described_class.by_platform("spotify")).to include(spotify_track)
        expect(described_class.by_platform("spotify")).not_to include(deezer_track)
      end
    end
  end

  describe "concerns" do
    it "includes MusicPlatforms module" do
      expect(described_class.included_modules).to include(MusicPlatforms)
    end
  end
end
