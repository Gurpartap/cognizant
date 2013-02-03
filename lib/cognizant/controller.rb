require "cognizant/daemon"

module Cognizant
  module Controller
    class << self
      attr_accessor :daemon
    end

    def self.daemon
      @daemon ||= Cognizant::Daemon.new
    end

    def self.load_daemon(options = {})
      self.daemon.load(options)
    end
  end
end
