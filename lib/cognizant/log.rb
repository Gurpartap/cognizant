module Cognizant
  module Log
    def self.[](name)
      Logging.logger[name]
    end
  end
end
