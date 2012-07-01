require "eventmachine"

module Cognizant
  module Client
    class Interface
      def initialize(server = nil)
        @sock = EventMachine.connect(server, Client::Interface::Handler)
      end

      def method_missing(*meth, &blk)
        @sock.queue << blk
        @sock.send_object(meth)
      end

      class Handler < EventMachine::Connection
        # include EventMachine::Protocols::SASLauthclient
        include EventMachine::Protocols::ObjectProtocol

        attr_reader :queue

        def post_init
          @queue = []
        end

        def receive_object(obj)
          if callback = @queue.shift
            callback.call(obj)
          end
        end
      end
    end
  end
end
