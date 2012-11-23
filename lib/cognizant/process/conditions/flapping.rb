require "cognizant/util/rotational_array"

module Cognizant
  class Process
    module Conditions
      class Flapping < TriggerCondition
        TRIGGER_STATES = [:starting, :restarting]

        attr_accessor :times, :within, :retry_after
        attr_reader :timeline

        def initialize(process, options = {})
          options = { :times => 5, :within => 1, :retry_after => 5 }.merge(options)

          options.each_pair do |name, value|
            self.send("#{name}=", value) if self.respond_to?("#{name}=")
          end

          @timeline = Util::RotationalArray.new(@times)
          super
        end

        def notify(transition)
          if TRIGGER_STATES.include?(transition.to_name)
            self.timeline << Time.now.to_i
            self.check_flapping
          end
        end

        def reset!
          @timeline.clear
          super
        end

        def check_flapping
          # The process has not flapped if we haven't encountered enough incidents.
          return unless (@timeline.compact.length == self.times)

          # Check if the incident happend within the timeframe.
          duration = (@timeline.last - @timeline.first) <= self.within

          if duration
            puts "Flapping detected: retrying in #{self.retry_after} seconds"

            self.schedule_event(:start, self.retry_after) unless self.retry_after == 0 # retry_after zero means "do not retry, ever".
            self.schedule_event(:unmonitor, 0)

            @timeline.clear

            # This will prevent a transition from happening in the process state_machine.
            throw :halt
          end
        end
      end
    end
  end
end
