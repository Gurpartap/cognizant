module Cognizant
  module System
    module ProcessStatus
      def self.exists?(pid = 0)
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

      def self.stop(pid, options = {})
        # Return if the process is already stopped.
        return true unless self.exists?(pid)

        signals = options[:signals] || ["TERM", "INT", "KILL"]
        timeout = options[:timeout] || 10

        catch :stopped do
          signals.each do |stop_signal|
            # Send the stop signal and wait for it to stop.
            self.signal(stop_signal, pid)

            # Poll to see if it's stopped yet. Minimum 2 so that we check at least once again.
            ([timeout / signals, 2].max).times do
              throw :stopped unless self.exists?(pid)
              sleep 1
            end
          end
        end
        not self.exists?(pid)
      end

      def self.signal(signal, pid)
        ::Process.kill(signal, pid)
      end
    end
  end
end
