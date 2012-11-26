require "active_support/core_ext/numeric"
require "active_support/duration"

module Cognizant
  def self.monitor(process_name = nil, attributes = {}, &block)
    Cognizant::Daemon.monitor(process_name, attributes, &block)
  end
end
