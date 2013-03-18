module Cognizant
  module Commands
    command("shutdown", "Stop the monitoring daemon without affecting managed processes") do |connection, _|
      Cognizant::Controller.daemon.shutdown!
    end
  end
end
