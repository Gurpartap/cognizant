module Cognizant
  module Server
    class Interface < EventMachine::Connection
      include EM::Protocols::SASLauth

      def post_init
        puts "-- someone connected to the echo server!"
      end

      def receive_data data
        send_data ">>>you sent: #{data}"
        close_connection if data =~ /quit/i
      end

      def unbind
        puts "-- someone disconnected from the echo server!"
      end

      def validate(usr, psw, sys, realm)
        usr == TestUser and psw == TestPsw
      end
    end
  end
end
