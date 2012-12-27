require "cognizant/system"

module Cognizant
  class Process
    module Conditions
      class CpuUsage < PollCondition
        def run(pid)
          # Check for current value for the given process pid.
          Cognizant::System.cpu_usage(pid).to_f
        end

        def check(value)
          # Evaluate the value with threshold.
          # The result of this decides condition invoking.
          value > @options[:above].to_f
        end
      end
    end
  end
end
