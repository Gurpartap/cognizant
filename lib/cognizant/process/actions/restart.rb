module Cognizant
  class Process
    module Actions
      module Restart
        # Environment variables for process during restart.
        # @return [Hash] Defaults to {}
        attr_accessor :restart_env

        # The command to run before the process is restarted. The exit status
        # of this command determines whether or not to proceed.
        # @return [String] Defaults to nil
        attr_accessor :restart_before_command

        # The command to restart the process with. This command can optionally
        # be similar in behavior to the stop command, since the process will
        # anyways be automatically started again, if autostart is set to true.
        # @return [String] Defaults to nil
        attr_accessor :restart_command

        # The signals to pass to the process one by one attempting to restart
        # it. Each signal is passed within the timeout period over equally
        # divided intervals (min. 2 seconds). Override with signals without
        # "KILL" to never force kill the process.
        # e.g. ["TERM", "INT"]
        # @return [Array] Defaults to ["TERM", "INT", "KILL"]
        attr_accessor :restart_signals

        # The grace time period in seconds for the process to stop within
        # (for restart). Covers the time period for the restart command or
        # signals. After the timeout is over, the process is checked for
        # running status and if not stopped, it re-enters the auto start
        # lifecycle based on conditions.
        # @return [String] Defaults to 10
        attr_accessor :restart_timeout

        # The command to run after the process is restarted.
        # @return [String] Defaults to nil
        attr_accessor :restart_after_command

        def restart_process
          result_handler = Proc.new do |result|
            # If it is a boolean and value is true OR if it's an execution result and it succeeded.
            if (!!result == result and result) or (result.respond_to?(:succeeded?) and result.succeeded?)
              unlink_pid unless pid_running? and self.daemonize
              # TODO: write_pid ?
            end
          end
          execute_action(
            result_handler,
            env:     (self.env || {}).merge(self.restart_env || {}),
            before:  self.restart_before_command,
            command: self.restart_command,
            signals: self.restart_signals,
            after:   self.restart_after_command,
            timeout: self.restart_timeout || 10
          )
        end
      end
    end
  end
end
