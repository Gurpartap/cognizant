module Cognizant
  class Process
    module Triggers
      class Trigger
        def notify(transition)
          raise "Implement in subclass"
        end

        def reset!
          raise "Implement in subclass"
        end
      end
    end
  end
end
