require "cognizant/server/daemon"

module Cognizant
  module Server

    def self.start(options = {})
      @daemon = Cognizant::Server::Daemon.new(options)
      @daemon.bootup
    end

    def self.daemon
      @daemon
    end
  end
end
