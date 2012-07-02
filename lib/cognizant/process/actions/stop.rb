module Cognizant
  class Process
    module Actions
      module Stop
        # Environment variables for process during stop.
        # @return [Hash] Defaults to {}
        attr_accessor :stop_env

        # The command to run before the stop command is run. The exit status
        # of this command determines whether or not to run the stop command.
        # @return [String] Defaults to nil
        attr_accessor :stop_before_command

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
        # Covers the time period for the stop command or signals. After the
        # timeout is over, the process is checked for running status and if
        # not stopped, it re-enters the auto start lifecycle based on
        # conditions.
        # @return [String] Defaults to 10
        attr_accessor :stop_timeout

        # The command to run after the process is stopped.
        # @return [String] Defaults to nil
        attr_accessor :stop_after_command

        def stop_process
          result_handler = Proc.new do |result|
            # If it is a boolean and value is true OR if it's an execution result and it succeeded.
            if (!!result == result and result) or (result.respond_to?(:succeeded?) and result.succeeded?)
              unlink_pid unless pid_running?
            end
          end
          execute_action(
            result_handler,
            env:     (self.env || {}).merge(self.stop_env || {}),
            before:  self.stop_before_command,
            command: self.stop_command,
            signals: self.stop_signals,
            after:   self.stop_after_command,
            timeout: self.stop_timeout
          )
        end
      end
    end
  end
end
