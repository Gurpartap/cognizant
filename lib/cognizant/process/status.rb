require "cognizant/system/process"

module Cognizant
  class Process
    module Status
      def pid_running?
        Cognizant::System::Process.pid_running?(read_pid)
      end

      def signal(signal, pid = nil)
        Cognizant::System::Process.signal(signal, (pid || read_pid))
      end
    end
  end
end
