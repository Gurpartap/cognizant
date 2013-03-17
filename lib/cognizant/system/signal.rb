module Cognizant
  module System
    module Signal
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def signal(signal, pid)
          ::Process.kill(signal, pid) if pid and pid != 0
        end

        def send_signals(pid, options = {})
          # Return if the process is not running.
          return true unless pid_running?(pid)

          signals = options[:signals] || ["TERM", "INT", "KILL"]
          timeout = options[:timeout] || 30

          catch :stopped do
            signals.each do |stop_signal|
              # Send the stop signal and wait for it to stop.
              signal(stop_signal, pid)

              # Poll to see if it's stopped yet. Minimum 2 so that we check at least once again.
              ([timeout / signals.size, 2].max).times do
                throw :stopped unless pid_running?(pid)
                sleep 1
              end
            end
          end
          not pid_running?(pid)
        end
      end
    end
  end
end
