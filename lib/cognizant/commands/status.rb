module Cognizant
  module Commands
    command("status", "Display status of managed process(es) or group(s)") do |connection, request|
      if request.has_key?("app") and request["app"].to_s.size > 0 and Cognizant::Controller.daemon.applications.has_key?(request["app"].to_sym)
        send_process_or_group_status(request["app"], request["args"])
      else
        %Q{No such application: "#{request['app']}"}
      end
    end
  end
end
