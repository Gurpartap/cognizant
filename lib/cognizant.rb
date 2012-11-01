require "cognizant/server"

module Cognizant
  def self.monitor(process_name, &block)
    Cognizant::Server.daemon.monitor(process_name, &block)
  end
end
