module Cognizant
  class Process
    module Triggers
      class Transition < Trigger
        def initialize(options = {}, &block)
          @from = [*options[:from]]
          @to = [*options[:to]]
          @do = block
        end

        def notify(transition)
          if @from.include?(transition.from_name) and @to.include?(transition.to_name)
            @do.call if @do and @do.respond_to?(:call)
          end
        end

        def reset!
        end
      end
    end
  end
end
