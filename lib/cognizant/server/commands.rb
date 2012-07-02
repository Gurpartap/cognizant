module Cognizant
  module Server
    module Commands
      def self.status
        yield("OK")
      end

      def self.shutdown
        Cognizant::Server.daemon.shutdown
        yield("OK")
      end
    end
  end
end
