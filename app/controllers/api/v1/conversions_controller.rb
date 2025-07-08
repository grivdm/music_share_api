module Api
  module V1
    class ConversionsController < ApplicationController
      def create
        url = extract_url_param
        return render_error("URL parameter is required", :bad_request) unless url.present?

        result = LinkConverterService.new.convert_url(url)
        render json: result, status: :ok
      rescue LinkConverterService::Error => e
        Rails.logger.error "Conversion error: #{e.message}"
        render_error(e.message, :unprocessable_entity)
      rescue StandardError => e
        Rails.logger.error "Unexpected error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render_error("An unexpected error occurred", :internal_server_error)
      end

      private

      def extract_url_param
        params[:url] || params.dig(:conversion, :url)
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end
    end
  end
end
