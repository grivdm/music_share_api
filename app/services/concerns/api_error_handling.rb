module ApiErrorHandling
  extend ActiveSupport::Concern

  private

  def handle_api_error(response, service_name)
    error_message = extract_error_message(response)
    log_api_error(service_name, response.code, error_message, response.body)

    raise MusicPlatformService::Error, "#{service_name} API Error: #{response.code} #{error_message}" if response.code >= 500
  end

  def extract_error_message(response)
    return response.message unless response.parsed_response.is_a?(Hash)

    error_data = response.parsed_response["error"]
    return response.message unless error_data

    error_data.is_a?(Hash) ? error_data["message"] : error_data
  end

  def log_api_error(service_name, code, message, body = nil)
    Rails.logger.error "#{service_name} API Error: #{code} #{message}"
    Rails.logger.error "Response body: #{body}" if body.present?
  rescue => e
    Rails.logger.error "Error handling #{service_name} error response: #{e.message}"
  end
end
