module Cognizant
  module Process
    module Attributes
      module Restart
        # The command to restart the process with. This command should be similar
        # in behavior to the stop command, since the process will anyways be
        # automatically started again, if autostart is set to true.
        # @return [String] Defaults to nil
        attr_accessor :restart_command

        # The signals to pass to the process one by one attempting to restart it.
        # Each signal is passed within the timeout period over equally
        # distributed intervals (min. 2 seconds). Override with signals without
        # "KILL" to never force kill a process.
        # e.g. ["TERM", "INT"]
        # @return [Array] Defaults to ["TERM", "INT", "KILL"]
        attr_accessor :restart_signals

        # The grace time period in seconds for the process to stop within
        # (for restart). After the timeout is over, the process is checked for
        # running status and if not stopped, it re-enters the auto start lifecycle
        # based on conditions.
        # @return [String] Defaults to 10
        attr_accessor :restart_timeout
      end
    end
  end
end
