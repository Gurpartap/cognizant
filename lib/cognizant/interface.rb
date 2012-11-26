require "eventmachine"

require "cognizant/commands"

module Cognizant
  class Interface < EventMachine::Connection

    attr_accessor :authenticated, :username, :password

    def post_init
      @authenticated = false
      @username      = nil
      @password      = nil
      if Cognizant.daemon.username and Cognizant.daemon.password
        post_authentication_challenge
      end
    end

    def receive_data(args)
      if not @authenticated and (Cognizant.daemon.username and Cognizant.daemon.password)
        return post_authentication_challenge(args.to_s)
      end

      args = [*args.split]
      command = args.shift.to_s.strip.downcase
      if command.size > 0
        begin
          Commands.send(command, *args) do |response|
            send_data "#{response}"
          end
        rescue => e
          send_data "#{e.message}"
        end
      end
      close_connection_after_writing
    end

    def unbind
      @authenticated = false
      # puts "-- someone disconnected from the server!"
    end

    def post_authentication_challenge(data = nil)
      data = data.to_s.strip
      if data.to_s.size > 0
        if @username
          @password = data
        else
          @username = data
        end
      end

      unless @username.to_s.size > 0
        if Cognizant.daemon.username and Cognizant.daemon.username.size != nil
          send_data "Username: "
          return
        end
      end

      unless @password.to_s.size > 0
        if Cognizant.daemon.password and Cognizant.daemon.password.size != nil
          send_data "Password: "
          return
        end
      end

      if @username and @password
        validate
      end
    end

    def validate
      @authenticated = @username == Cognizant.daemon.username and @password == Cognizant.daemon.password
      @username = nil
      @password = nil
      if @authenticated
        send_data "Authenticated. Welcome!\r\n\r\n"
      else
        send_data "Authentication failed.\r\n\r\n"
        post_authentication_challenge
      end
    end
  end
end
