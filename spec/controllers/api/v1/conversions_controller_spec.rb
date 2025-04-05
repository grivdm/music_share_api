require 'rails_helper'

RSpec.describe Api::V1::ConversionsController, type: :controller do
  describe "POST #create" do
    context "with valid url parameter" do
      let(:valid_params) { { url: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT" } }
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

      it "returns a successful response" do
        post :create, params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it "returns track information with links" do
        post :create, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('track')
        expect(json_response).to have_key('links')
        expect(json_response['track']).to include('title', 'artist')
        expect(json_response['links']).to include('spotify')
      end
    end

    context "with invalid url parameter" do
      it "returns 400 bad request when url is missing" do
        post :create, params: {}
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 422 unprocessable entity for unsupported platform" do
        post :create, params: { url: "https://music.apple.com/track/123456" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with unexpected errors" do
      before do
        allow_any_instance_of(LinkConverterService).to receive(:convert_url).and_raise(StandardError, "Unexpected error")
      end

      it "returns 500 internal server error" do
        post :create, params: { url: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT" }
        expect(response).to have_http_status(:internal_server_error)
      end

      it "returns error message" do
        post :create, params: { url: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT" }
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
    end
  end
end
