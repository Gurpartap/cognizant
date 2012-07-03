module Cognizant
  class Process
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

      def signal(signal, pid = nil)
        ::Process.kill(signal, (pid || read_pid))
      end
    end
  end
end
