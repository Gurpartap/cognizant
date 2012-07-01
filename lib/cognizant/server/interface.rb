require "eventmachine"

module Cognizant
  module Server
    class Interface < EventMachine::Connection
      include EventMachine::Protocols::ObjectProtocol
      # include EventMachine::Protocols::SASLauth

      def post_init
        @obj = Hash.new
        puts "-- someone connected to the echo server!"
      end

      def receive_object(method)
        send_object @obj.send(*method)
      end

      def unbind
        @obj = nil
        puts "-- someone disconnected from the echo server!"
      end

      # def validate(usr, psw, sys, realm)
      #   usr == TestUser and psw == TestPsw
      # end
    end
  end
end
