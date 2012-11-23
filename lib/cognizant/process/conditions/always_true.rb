module Cognizant
  class Process
    module Conditions
      class AlwaysTrue < PollCondition
        def run(pid)
          1
        end

        def check(value)
          true
        end
      end
    end
  end
end
