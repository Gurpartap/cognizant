require "cognizant/system"

module Cognizant
  class Process
    module Status
      def pid_running?
        Cognizant::System.pid_running?(read_pid)
      end

      def signal(signal, pid = nil)
        Cognizant::System.signal(signal, (pid || read_pid))
      end
    end
  end
end
