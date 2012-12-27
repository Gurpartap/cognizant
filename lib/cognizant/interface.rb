require "eventmachine"

require "cognizant/commands"

module Cognizant
  class Interface < EventMachine::Connection
    def post_init
    end

    def receive_data(args)
      Cognizant::Commands.process_command(self, args)
    end

    def unbind
    end
  end
end
