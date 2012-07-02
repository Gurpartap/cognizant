module Cognizant
  module Process
    module Attributes
      module Stop
        # The command to stop the process with.
        # e.g. "/usr/bin/redis-server"
        # @return [String] Defaults to nil
        attr_accessor :stop_command

        # The signals to pass to the process one by one attempting to stop it.
        # Each signal is passed within the timeout period over equally
        # distributed intervals (min. 2 seconds). Override with signals without
        # "KILL" to never force kill a process.
        # e.g. ["TERM", "INT"]
        # @return [Array] Defaults to ["TERM", "INT", "KILL"]
        attr_accessor :stop_signals

        # The grace time period in seconds for the process to stop within.
        # After the timeout is over, the process is checked for running status
        # and if not stopped, it re-enters the auto start lifecycle based on
        # conditions.
        # @return [String] Defaults to 10
        attr_accessor :stop_timeout
      end
    end
  end
end
