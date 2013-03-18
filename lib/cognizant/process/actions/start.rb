module Cognizant
  class Process
    module Actions
      module Start
        # Environment variables for process during start.
        # @return [Hash] Defaults to {}
        attr_accessor :start_env

        # The command to run before the process is started. The exit status
        # of this command determines whether or not to proceed.
        # @return [String] Defaults to nil
        attr_accessor :start_before_command

        # The command to start the process with.
        # e.g. "/usr/bin/redis-server"
        # @return [String] Defaults to nil
        attr_accessor :start_command

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

        # The grace time period in seconds for the process to start within.
        # Covers the time period for the input and start command. After the
        # timeout is over, the process is considered as not started and it
        # re-enters the auto start lifecycle based on conditions.
        # @return [String] Defaults to 30
        attr_accessor :start_timeout

        # The command to run after the process is started.
        # @return [String] Defaults to nil
        attr_accessor :start_after_command

        def reset_attributes!
          self.start_env = {}
          self.start_before_command = nil
          self.start_command = nil
          self.start_with_input = nil
          self.start_with_input_file = nil
          self.start_with_input_command = nil
          self.start_timeout = 30
          self.start_after_command = nil
          super
        end

        def start_process
          # We skip so that we're not reinformed about the required transition by the tick.
          skip_ticks_for(self.start_timeout)

          options = {
            name:          self.name,
            daemonize:     self.daemonize,
            env:           self.env.merge(self.start_env),
            logfile:       self.logfile,
            errfile:       self.errfile,
            before:        self.start_before_command,
            command:       self.start_command,
            input:         self.start_with_input,
            input_file:    self.start_with_input_file,
            input_command: self.start_with_input_command,
            after:         self.start_after_command,
            timeout:       self.start_timeout
          }
          handle_action('_start_result_handler', options)
        end

        # @private
        def _start_result_handler(result, time_left = 0)
          if result.respond_to?(:succeeded?) and result.succeeded?
            write_pid(result.pid) if self.daemonize and result.pid != 0
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
