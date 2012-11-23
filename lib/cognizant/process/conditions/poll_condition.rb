module Cognizant
  class Process
    module Conditions
      class PollCondition
        def initialize(options = {})
          @options = options
        end

        def run(pid)
          raise "Implement in subclass!"
        end

        def check(value)
          raise "Implement in subclass!"
        end

        def format_value(value)
          value
        end
      end
    end
  end
end
