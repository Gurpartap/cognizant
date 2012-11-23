module Cognizant
  class Process
    module Conditions
      class MemoryUsage < Condition
        MB = 1024 ** 2
        FORMAT_STR = "%d%s"
        MB_LABEL = "MB"
        KB_LABEL = "KB"

        def initialize(options = {})
          @above = options[:above].to_f
        end

        def run(pid)
          System.memory_usage(pid).to_f
        end

        def check(value)
          value.kilobytes > @above
        end

        def format_value(value)
          if value.kilobytes >= MB
            FORMAT_STR % [(value / 1024).round, MB_LABEL]
          else
            FORMAT_STR % [value, KB_LABEL]
          end
        end
      end
    end
  end
end
