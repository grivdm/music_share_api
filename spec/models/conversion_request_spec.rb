require 'rails_helper'

RSpec.describe ConversionRequest, type: :model do
  subject(:conversion_request) { build(:conversion_request) }

  it "has a valid factory" do
    expect(conversion_request).to be_valid
  end

  describe "validations" do
    it { should validate_presence_of(:source_url) }
    it { should validate_inclusion_of(:source_platform).in_array(MusicPlatforms::PLATFORMS) }

    context "source_platform validation" do
      it "requires source_platform when not set via callback" do
        conversion_request.source_platform = ""
        expect(conversion_request).not_to be_valid
        expect(conversion_request.errors[:source_platform]).to include("can't be blank")
      end
    end

    describe "URL format validation" do
      it "validates source_url format" do
        conversion_request.source_url = "invalid-url"
        expect(conversion_request).not_to be_valid
        expect(conversion_request.errors[:source_url]).to include("is invalid")
      end

      it "allows valid URL format" do
        conversion_request.source_url = "https://open.spotify.com/track/123"
        expect(conversion_request).to be_valid
      end
    end
  end

  describe "callbacks" do
    describe "before_validation" do
      context "when source_platform is not set" do
        it "sets default platform to spotify" do
          request = build(:conversion_request, source_platform: nil)
          request.valid?
          expect(request.source_platform).to eq("spotify")
        end
      end

      context "when source_platform is already set" do
        it "does not override existing platform" do
          request = build(:conversion_request, source_platform: "deezer")
          request.valid?
          expect(request.source_platform).to eq("deezer")
        end
      end
    end
  end

  describe "constants" do
    it "has PLATFORMS constant that matches MusicPlatforms::PLATFORMS" do
      expect(described_class::PLATFORMS).to eq(MusicPlatforms::PLATFORMS)
    end
  end
end
