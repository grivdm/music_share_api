class HealthController < ApplicationController
  def index
    health_status = { status: "ok", timestamp: Time.now.iso8601 }

    begin
      db_result = ActiveRecord::Base.connection.execute("SELECT 1")
      health_status[:database] = "ok"
    rescue => e
      health_status[:database] = "error"
      health_status[:database_error] = e.message
      health_status[:status] = "error"
    end

    if defined?(APP_VERSION)
      health_status[:version] = APP_VERSION
    end
    status_code = health_status[:status] == "ok" ? :ok : :service_unavailable
    render json: health_status, status: status_code
  end
end
