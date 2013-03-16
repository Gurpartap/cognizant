require "cognizant/daemon"

module Cognizant
  module Controller
    class << self
      attr_accessor :daemon
    end

    def self.daemon
      @daemon ||= Cognizant::Daemon.new
    end

    def self.start_daemon(options = {})
      self.daemon.start(options)
    end
  end
end
