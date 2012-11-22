module Cognizant
  module System
    module Process
      def self.pid_running?(pid)
        return false unless pid and pid != 0
        self.signal(0, pid)
        # It's running since no exception was raised.
        true
      rescue Errno::ESRCH
        # No such process.
        false
      rescue Errno::EPERM
        # Probably running, but we're not allowed to pass signals.
        # TODO: Is this a sign of problems ahead?
        true
      else
        # Possibly running.
        true
      end

      def self.signal(signal, pid)
        ::Process.kill(signal, pid) if pid and pid != 0
      end

      def self.send_signals(pid, options = {})
        # Return if the process is not running.
        return true unless self.pid_running?(pid)

        signals = options[:signals] || ["TERM", "INT", "KILL"]
        timeout = options[:timeout] || 10

        catch :stopped do
          signals.each do |stop_signal|
            # Send the stop signal and wait for it to stop.
            self.signal(stop_signal, pid)

            # Poll to see if it's stopped yet. Minimum 2 so that we check at least once again.
            ([timeout / signals.size, 2].max).times do
              throw :stopped unless self.pid_running?(pid)
              sleep 1
            end
          end
        end
        not self.pid_running?(pid)
      end
    end
  end
end
