module Cognizant
  module Process
    module Attributes
      module Start
        # The command to start the process with.
        # e.g. "/usr/bin/redis-server"
        # @return [String] Defaults to nil
        attr_accessor :start_command

        # The grace time period in seconds for the process to start within.
        # After the timeout is over, the process the considered not started
        # and it re-enters the auto start lifecycle based on conditions.
        # @return [String] Defaults to 10
        attr_accessor :start_timeout

        # Start the process with this in it's STDIN.
        # e.g. "daemonize no"
        # @return [String] Defaults to nil
        attr_accessor :start_with_input

        # Start the process with this file's data in it's STDIN.
        # e.g. "/etc/redis/redis.conf"
        # @return [String] Defaults to nil
        attr_accessor :start_with_input_file

        # Start the process with this command's output in it's (process') STDIN.
        # e.g. "cat /etc/redis/redis.conf"
        # @return [String] Defaults to nil
        attr_accessor :start_with_input_command
      end
    end
  end
end
