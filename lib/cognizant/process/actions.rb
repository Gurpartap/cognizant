require "cognizant/system/exec"

require "cognizant/process/actions/start"
require "cognizant/process/actions/stop"
require "cognizant/process/actions/restart"

module Cognizant
  class Process
    module Actions
      include Cognizant::Process::Actions::Start
      include Cognizant::Process::Actions::Stop
      include Cognizant::Process::Actions::Restart

      private

      def run_options(overrides = {})
        options = {}
        # CONFIGURABLE_ATTRIBUTES.each do |o|
        #   options[o] = self.send(o)
        # end
        options.merge(overrides)
      end

      def run(command, overrides = {})
        options = {}
        options = run_options({ daemonize: false }.merge(overrides)) if overrides
        System::Execute.command(command, options)
      end

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
