module Api
  module V1
    class ConversionsController < ApplicationController
      def create
        Rails.logger.debug "Received params: #{params.inspect}"
        url = params[:url] || params.dig(:conversion, :url)
        Rails.logger.debug "Extracted URL: #{url}"
        unless url.present?
          render json: { error: "URL parameter is required" }, status: :bad_request
          return
        end

        converter = LinkConverterService.new
        begin
          result = converter.convert_url(url)
          render json: result, status: :ok
        rescue LinkConverterService::Error => e
          Rails.logger.error "Conversion error in controller: #{e.message}"
          render json: { error: e.message }, status: :unprocessable_entity
        rescue StandardError => e
          Rails.logger.error "Unexpected error in controller: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "An unexpected error occurred" }, status: :internal_server_error
        end
      end
    end
  end
end
