require "cognizant/process/actions/start"
require "cognizant/process/actions/stop"
require "cognizant/process/actions/restart"
require "cognizant/system"

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
        timeout        = options[:timeout]

        # TODO: Works well but can some refactoring make it more declarative?
        @action_thread = Thread.new do
          result = false
          queue = Queue.new
          thread = Thread.new do
            # If before_command succeeds, we move to the next command.
            (before_command and not success = run(before_command).succeeded?) or
            # If the command is available and it succeeds, we stop here.
            (command and success = run(command, options) and success.succeeded?) or
            # As a last try, check for signals. If the action has set signals, then it can handle it's result.
            (success = send_signals(signals: signals, timeout: timeout))

            run(after_command) if success and after_command
            queue.push(success)
            Thread.exit
          end

          time_left = timeout
          while time_left >= 0 do
            # If there is something in the queue, we have the required result.
            unless queue.empty?
              result = queue.pop
              break
            end
            sleep 1
            time_left -= 1
          end

          # TODO: Unmonitor if timed out?

          # Kill the nested thread.
          thread.kill

          # Action callback.
          result_handler.call(result, time_left) if result_handler.respond_to?(:call)
        end
      end

      def send_signals(options = {})
        # Return if the process is already stopped.
        return true unless pid_running?
        Cognizant::System.send_signals(@process_pid, options)
        not pid_running?
      end
    end
  end
end
