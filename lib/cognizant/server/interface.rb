require "eventmachine"

require "cognizant/server/commands"

module Cognizant
  module Server
    class Interface < EventMachine::Connection
      def post_init
        # puts "-- someone connected to the server!"
      end

      def receive_data(command)
        command = command.strip.downcase
        if Commands.respond_to?(command)
          Commands.send(command) do |response|
            send_data "#{response}\r\n\r\n"
          end
        else
          send_data "No such command: #{command}\r\n\r\n"
        end
        close_connection_after_writing
      end

      def unbind
        # puts "-- someone disconnected from the server!"
      end
    end
  end
end

# module Cognizant
#   module Server
#     class Interface < EventMachine::Connection
#       include EventMachine::Protocols::ObjectProtocol
#       # include EventMachine::Protocols::SASLauth
# 
#       def post_init
#         @obj = Hash.new
#         puts "-- someone connected to the echo server!"
#       end
# 
#       def receive_object(method)
#         send_object @obj.send(*method)
#       end
# 
#       def unbind
#         @obj = nil
#         puts "-- someone disconnected from the echo server!"
#       end
# 
#       # def validate(usr, psw, sys, realm)
#       #   usr == TestUser and psw == TestPsw
#       # end
#     end
#   end
# end
