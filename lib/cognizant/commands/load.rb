module Cognizant
  module Commands
    command("load", "Loads the process information from specified Ruby file") do |connection, request|
      request["args"].each do |file|
        Cognizant::Controller.daemon.load_file(file)
      end
      "OK"
    end
  end
end
