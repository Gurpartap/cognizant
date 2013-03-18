module Cognizant
  module Commands
    command("use", "Switch the current application for use with process maintenance commands") do |connection, request|
      puts "Cognizant::Controller.daemon.applications.keys: #{Cognizant::Controller.daemon.applications.keys}"
      if request["args"].size > 0 and request["args"].first.to_s.size > 0 and Cognizant::Controller.daemon.applications.has_key?(request["args"].first.to_sym)
        app = request["args"].first
        message = "OK"
      else
        app = request["app"]
        message = %Q{No such application: "#{request['args'].first}"}
      end
      { "use" => app, "message" => message }
    end
  end
end
