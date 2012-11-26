require "active_support/core_ext/numeric"
require "active_support/duration"

require "cognizant/daemon"

module Cognizant
  def self.start_daemon(options = {})
    @daemon = Cognizant::Daemon.new(options)
    @daemon.bootup
  end

  def self.daemon
    @daemon
  end

  def self.monitor(process_name = nil, attributes = {}, &block)
    Cognizant.daemon.monitor(process_name, attributes, &block)
  end
end
