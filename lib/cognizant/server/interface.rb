require "json"
require "eventmachine"

require "cognizant/server/commands"

module Cognizant
  module Server
    class Interface < EventMachine::Connection
      def post_init
        # puts "-- someone connected to the server!"
      end

      def receive_data(args)
        args = [*args.split]
        command = args.shift.to_s.strip.downcase
        if command.size > 0
          begin
            Commands.send(command, *args) do |response|
              send_data "#{response.to_json}\r\n\r\n"
            end
          rescue => e
            send_data "#{e.inspect.to_json}\r\n\r\n"
          end
        end
        # close_connection_after_writing
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
