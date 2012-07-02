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
        # timeout is over, the process the considered not started and it
        # re-enters the auto start lifecycle based on conditions.
        # @return [String] Defaults to 10
        attr_accessor :start_timeout

        # The command to run after the process is started.
        # @return [String] Defaults to nil
        attr_accessor :start_after_command

        def start_process
          result_handler = Proc.new do |result|
            if result.respond_to?(:succeeded?) and result.succeeded?
              write_pid(result.pid) if result.pid != 0
            end
          end
          execute_action(
            result_handler,
            name:      self.name,
            daemonize: self.daemonize || true,
            env:       (self.env || {}).merge(self.start_env || {}),
            logfile:   self.logfile,
            errfile:   self.errfile,
            before:    self.start_before_command,
            command:   self.start_command,
            after:     self.start_after_command,
            timeout:   self.start_timeout
          )
        end
      end
    end
  end
end
