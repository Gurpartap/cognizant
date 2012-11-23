require "cognizant/system"

module Cognizant
  class Process
    module Conditions
      class CpuUsage < Condition
        def initialize(options = {})
          @above = options[:above].to_f
        end

        def run(pid)
          System.cpu_usage(pid).to_f
        end

        def check(value)
          value > @above
        end
      end
    end
  end
end
