require 'rails_helper'

RSpec.describe "Api::V1::Conversions", type: :request do
  describe "POST /api/v1/convert" do
    let(:spotify_url) { "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT" }
    let(:track_data) {
      {
        track: {
          title: "Never Gonna Give You Up",
          artist: "Rick Astley",
          album: "Whenever You Need Somebody",
          isrc: "GBARL0700477"
        },
        links: {
          spotify: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT",
          deezer: "https://www.deezer.com/track/3135556"
        }
      }
    }

    before do
      allow_any_instance_of(LinkConverterService).to receive(:convert_url).and_return(track_data)
    end

    it "converts spotify url to all available platforms" do
      post "/api/v1/convert", params: { url: spotify_url }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)

      expect(json_response['track']['title']).to eq("Never Gonna Give You Up")
      expect(json_response['track']['artist']).to eq("Rick Astley")
      expect(json_response['links']).to have_key('spotify')
      expect(json_response['links']).to have_key('deezer')
    end

    context "with malformed request" do
      it "returns error for missing url" do
        post "/api/v1/convert", params: {}

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
    end
  end
end
