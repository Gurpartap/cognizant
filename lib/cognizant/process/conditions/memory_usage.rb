module Cognizant
  class Process
    module Conditions
      class MemoryUsage < PollCondition
        MB = 1024 ** 2
        FORMAT_STR = "%d%s"
        MB_LABEL = "MB"
        KB_LABEL = "KB"

        def run(pid)
          Cognizant::System.memory_usage(pid).to_f
        end

        def check(value)
          value.kilobytes > @options[:above].to_f
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
