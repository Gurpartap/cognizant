module Cognizant
  module Process
    module Status
      def pid_running?
        pid = read_pid
        return false unless pid and pid != 0
        signal(0, pid)
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

      def stop_with_signals(options = {})
        # Return if the process is already stopped.
        return true unless pid_running?

        signals = options[:signals] || ["TERM", "INT", "KILL"]
        timeout = options[:timeout] || 10

        catch :stopped do
          signals.each do |stop_signal|
            # Send the stop signal and wait for it to stop.
            signal(stop_signal, @process_pid)

            # Poll to see if it's stopped yet. Minimum 2 so that we check at least once again.
            ([timeout / signals, 2].max).times do
              throw :stopped unless pid_running?
              sleep 1
            end
          end
        end
        not pid_running?
      end

      def signal(signal, pid = nil)
        ::Process.kill(signal, (pid || read_pid))
      end
    end
  end
end
