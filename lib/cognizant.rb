require "active_support/core_ext/numeric"
require "active_support/duration"

require "cognizant/server"

module Cognizant
  def self.monitor(process_name = nil, attributes = {}, &block)
    Cognizant::Server.daemon.monitor(process_name, attributes, &block)
  end
end
