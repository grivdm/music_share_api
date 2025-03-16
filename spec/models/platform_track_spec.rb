require 'rails_helper'

RSpec.describe PlatformTrack, type: :model do
  it "has a valid factory" do
    expect(build(:platform_track)).to be_valid
  end

  describe "validations" do
    it { should validate_presence_of(:platform) }
    it { should validate_presence_of(:platform_id) }
    it { should validate_presence_of(:url) }

    xit "validates uniqueness of platform_id scoped to platform" do
      create(:platform_track, platform: "spotify", platform_id: 'id123')
      duplicate = build(:platform_track, platform: "spotify", platform_id: 'id123')
      expect(duplicate).not_to be_valid
    end

    xit "validates uniqueness of platform scoped to track_id" do
      track = create(:track)
      create(:platform_track, track: track, platform: "spotify")
      duplicate = build(:platform_track, track: track, platform: "spotify")
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it { should belong_to(:track) }
  end
end
