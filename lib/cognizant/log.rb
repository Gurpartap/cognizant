require "logging"

module Cognizant
  module Log
    def self.logger
      Logging.logger
    end

    def self.[](name)
      self.logger[name]
    end

    def self.stdout
      Logging.appenders.stdout
    end

    def self.syslog(*args)
      Logging.appenders.syslog(*args)
    end

    def self.file(*args)
      Logging.appenders.file(*args)
    end
  end
end
