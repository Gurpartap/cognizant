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
        # Also see restart_expect variable.
        # @return [String] Defaults to nil
        attr_accessor :restart_command

        # The signals to pass to the process one by one attempting to restart
        # it. Each signal is passed within the timeout period over equally
        # divided intervals (min. 2 seconds). Override with signals without
        # "KILL" to never force kill the process.
        # Also see restart_expect variable.
        # e.g. ["TERM", "INT"]
        # @return [Array] Defaults to ["QUIT", "TERM", "INT"]
        attr_accessor :restart_signals

        # Whether or not the process is expected to stop itself after the
        # restart action is executed. If, upon restart action, the process will
        # stop but not start again by itself, it should be set to true. If the
        # process will start again within the timeout period, it should be set
        # to false. For convenience, it defaults to false, if restart_command
        # or restart_signals are set, as the restart action is then expected to
        # start itself after a stop.
        # @return [true, false] Defaults to !restart_command.present? ||
        # !restart_signals.present?
        attr_accessor :restart_expect_stopped

        # The grace time period in seconds for the process to stop within
        # (for restart). Covers the time period for the restart command or
        # signals. After the timeout is over, the process is checked for
        # running status and if not stopped, it re-enters the auto start
        # lifecycle based on conditions. Timeout of request has the same effect
        # as :stopped setting :restart_expect.
        # @return [String] Defaults to 30
        attr_accessor :restart_timeout

        # The command to run after the process is restarted.
        # @return [String] Defaults to nil
        attr_accessor :restart_after_command

        def restart_expect_stopped!
          self.restart_expect_stopped = true
        end

        def reset_attributes!
          self.restart_env = {}
          self.restart_before_command = nil
          self.restart_command = nil
          self.restart_signals = nil
          self.restart_expect_stopped = nil
          self.restart_timeout = 30
          self.restart_after_command = nil
          super
        end

        def restart_process
          # We skip so that we're not reinformed about the required transition by the tick.
          skip_ticks_for(self.restart_timeout)

          options = {
            env:      self.env.merge(self.restart_env),
            before:   self.restart_before_command,
            command:  self.restart_command,
            signals:  self.restart_signals || ["QUIT", "TERM", "INT"],
            after:    self.restart_after_command,
            timeout:  self.restart_timeout
          }
          handle_action('_restart_result_handler', options)
        end

        # @private
        def _restart_result_handler(result, time_left = 0)
          # If it is a boolean and value is true OR if it's an execution result and it succeeded.
          if (!!result == result and result) or (result.respond_to?(:succeeded?) and result.succeeded?)
            unlink_pid if not pid_running? and self.daemonize

            unless !!self.restart_expect_stopped == self.restart_expect_stopped
              self.restart_expect_stopped = !(self.restart_command.present? or self.restart_signals.present?)
            end

            # We are not resetting @process_pid here to give process a second of grace period.

            unless self.restart_expect_stopped
              while (time_left >= 0 and not process_running?) do
                sleep 1
                time_left -= 1
                @process_pid = nil
              end
            end
          else
            @process_pid = nil
          end

          # Rollback the pending skips.
          skip_ticks_for(-time_left) if time_left > 0
        end
      end
    end
  end
end
