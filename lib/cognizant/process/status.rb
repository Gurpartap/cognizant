require "cognizant/system"

module Cognizant
  class Process
    module Status
      def pid_running?
        Cognizant::System.pid_running?(cached_pid)
      end

      def signal(signal, pid = nil)
        Cognizant::System.signal(signal, (pid || cached_pid))
      end
    end
  end
end
