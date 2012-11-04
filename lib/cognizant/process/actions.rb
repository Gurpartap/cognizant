require "cognizant/process/actions/start"
require "cognizant/process/actions/stop"
require "cognizant/process/actions/restart"
require "cognizant/system/process"

module Cognizant
  class Process
    module Actions
      include Cognizant::Process::Actions::Start
      include Cognizant::Process::Actions::Stop
      include Cognizant::Process::Actions::Restart

      private

      def execute_action(result_handler, options)
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
            if before_command and not success = run(before_command).succeeded?
              queue.push(success)
              Thread.exit
            end

            if (command and success = run(command, options) and success.succeeded?)
              run(after_command) if after_command
              queue.push(success)
              Thread.exit
            end

            # If the caller has attempted to set signals, then it can handle it's result.
            if success = send_signals(signals: signals, timeout: timeout)
              run(after_command) if after_command
              queue.push(success)
              Thread.exit
            end

            queue.push(false)
            Thread.exit
          end

          timeout_left = timeout + 1
          while (timeout_left -= 1) > 0 do
            # If there is something in the queue, we have the required result.
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

      def send_signals(options = {})
        # Return if the process is already stopped.
        return true unless pid_running?
        Cognizant::System::Process.send_signals?(@process_pid, options)
        not pid_running?
      end
    end
  end
end
