module Cognizant
  class Process
    module Actions
      module Stop
        # Environment variables for process during stop.
        # @return [Hash] Defaults to {}
        attr_accessor :stop_env

        # The command to run before the process is stopped. The exit status
        # of this command determines whether or not to proceed.
        # @return [String] Defaults to nil
        attr_accessor :stop_before_command

        # The command to stop the process with.
        # e.g. "/usr/bin/redis-server"
        # @return [String] Defaults to nil
        attr_accessor :stop_command

        # The signals to pass to the process one by one attempting to stop it.
        # Each signal is passed within the timeout period over equally
        # divided intervals (min. 2 seconds). Override with signals without
        # "KILL" to never force kill the process.
        # e.g. ["TERM", "INT"]
        # @return [Array] Defaults to ["QUIT", "TERM", "INT"]
        attr_accessor :stop_signals

        # The grace time period in seconds for the process to stop within.
        # Covers the time period for the stop command or signals. After the
        # timeout is over, the process is checked for running status and if
        # not stopped, it re-enters the auto start lifecycle based on
        # conditions.
        # @return [String] Defaults to 30
        attr_accessor :stop_timeout

        # The command to run after the process is stopped.
        # @return [String] Defaults to nil
        attr_accessor :stop_after_command

        def reset_attributes!
          self.stop_env = {}
          self.stop_before_command = nil
          self.stop_command = nil
          self.stop_signals = ["QUIT", "TERM", "INT"]
          self.stop_timeout = 30
          self.stop_after_command = nil
          super
        end

        def stop_process
          # We skip so that we're not reinformed about the required transition by the tick.
          skip_ticks_for(self.stop_timeout)

          options = {
            env:      self.env.merge(self.stop_env),
            before:   self.stop_before_command,
            command:  self.stop_command,
            signals:  self.stop_signals,
            after:    self.stop_after_command,
            timeout:  self.stop_timeout
          }
          handle_action('_stop_result_handler', options)
        end

        # @private
        def _stop_result_handler(result, time_left = 0)
          # If it is a boolean and value is true OR if it's an execution result and it succeeded.
          if (!!result == result and result) or (result.respond_to?(:succeeded?) and result.succeeded?)
            unlink_pid if not pid_running? and self.daemonize
          end

          # Reset cached pid to read from file or command.
          @process_pid = nil

          # Rollback the pending skips.
          skip_ticks_for(-time_left) if time_left > 0
        end
      end
    end
  end
end
