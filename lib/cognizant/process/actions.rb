module Cognizant
  module Process
    module Actions
      def start_process
        result_handler = Proc.new do |result|
          if result.respond_to?(:succeeded) and result.succeeded
            write_pid(result.pid) if result.pid != 0
          end
        end
        execute_action(
          result_handler,
          daemonize: self.daemonize,
          # env:       (self.env || {}).merge(self.start_env || {}),
          # before:    self.start_before_command,
          command:   self.start_command,
          # after:     self.start_after_command,
          timeout:   self.start_timeout
        )
      end

      def stop_process
        result_handler = Proc.new do |result|
          # If it is a boolean and value is true OR if it's an execution result and it succeeded.
          if (!!result == result and result) or (result.respond_to?(:succeeded) and result.succeeded)
            unlink_pid unless pid_running?
          end
        end
        execute_action(
          result_handler,
          # env:     (self.env || {}).merge(self.stop_env || {}),
          # before:  self.stop_before_command,
          command: self.stop_command,
          signals: self.stop_signals,
          # after:   self.stop_after_command,
          timeout: self.stop_timeout
        )
      end

      def restart_process
        result_handler = Proc.new do |result|
          # If it is a boolean and value is true OR if it's an execution result and it succeeded.
          if (!!result == result and result) or (result.respond_to?(:succeeded) and result.succeeded)
            unlink_pid unless pid_running?
          end
        end
        execute_action(
          result_handler,
          # env:     (self.env || {}).merge(self.restart_env || {}),
          # before:  self.restart_before_command,
          command: self.restart_command,
          signals: self.restart_signals,
          # after:   self.restart_after_command,
          timeout: self.restart_timeout
        )
      end

      private

      def execute_action(result_handler, options)
        daemonize      = options[:daemonize] || false
        env            = options[:env]
        before_command = options[:before]
        command        = options[:command]
        after_command  = options[:after]
        signals        = options[:signals]
        timeout        = options[:timeout] || 10

        # TODO: Works well but can some refactoring make it more declarative?
        @action_thread = Thread.new do
          result = false
          queue = Queue.new
          thread = Thread.new do
            if before_command and not success = run(before_command).succeeded
              queue.push(success)
              Thread.exit
            end

            if (command and success = run(command, { daemonize: daemonize, env: env }) and success.succeeded)
              run(after_command) if after_command
              queue.push(success)
              Thread.exit
            end

            # If the caller has attempted to set signals, then it can handle it's result.
            if (options.has_key?(:signals) and success = stop_with_signals(signals: signals, timeout: timeout))
              run(after_command) if after_command
              queue.push(success)
              Thread.exit
            end

            queue.push(false)
            Thread.exit
          end

          timeout_left = timeout + 1
          while (timeout_left -= 1) > 0 do
            # If there is something in the queue, we have the required result. Simpler than Mutex#synchronize.
            if result = queue.pop
              # Rollback the pending skips, since we finished before timeout.
              skip_ticks_for(-timeout_left)
              break
            end
            sleep 1
          end
        
          # Kill the nested thread.
          thread.kill

          # Action callback.
          result_handler.call(result) if result_handler.respond_to?(:call)

          # Kill self.
          Thread.kill
        end

        # We skip so that we're not reinformed about the required transition by the tick.
        skip_ticks_for(timeout)
      end
    end
  end
end
