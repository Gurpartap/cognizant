require "cognizant/system"

module Cognizant
  class Process
    module Status
      def process_running?
        @process_running = begin
          if @ping_command and run(@ping_command).succeeded?
            true
          elsif pid_running?
            true
          else
            false
          end
        end
      end

      def pid_running?
        Cognizant::System.pid_running?(cached_pid)
      end

      def signal(signal, pid = nil)
        Cognizant::System.signal(signal, (pid || cached_pid))
      end
    end
  end
end
