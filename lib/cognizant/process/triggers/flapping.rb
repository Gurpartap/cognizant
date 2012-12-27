require "cognizant/util/rotational_array"

module Cognizant
  class Process
    module Triggers
      class Flapping < Trigger
        TRIGGER_STATES = [:starting, :restarting]

        attr_accessor :times, :within, :retry_after, :retries
        attr_reader :timeline

        def initialize(options = {})
          @times       = options[:times]       || 5
          @within      = options[:within]      || 1
          @retry_after = options[:retry_after] || 5
          @retries     = options[:retries]     || 0

          @timeline = Util::RotationalArray.new(@times)
          @num_of_tries = 0
        end

        def notify(transition)
          if TRIGGER_STATES.include?(transition.to_name)
            self.timeline << Time.now.to_i
            self.check_flapping
          end
        end

        def reset!
          @timeline.clear
          @num_of_tries = 0
        end

        def within_duration?
          (@timeline.last - @timeline.first) <= self.within
        end

        def can_retry?
          # retry_after = 0 means do not retry.
          self.retry_after > 0 and
          # retries = 0 means always retry.
          (self.retries == 0 or (self.retries > 0 and @num_of_tries <= self.retries))
        end

        def check_flapping
          # The process has not flapped if we haven't encountered enough incidents.
          return unless (@timeline.compact.length == self.times)

          # Check if the incident happend within the timeframe.
          if within_duration?
            @num_of_tries += 1

            puts "Flapping detected (##{@num_of_tries}) for #{@delegate.process.name}(pid:#{@delegate.process.cached_pid})."

            # 0.1 to ensure the state isn't randomly caught in throw :halt below.
            @delegate.schedule_event(:unmonitor, [0.1, self.retry_after].min)
            @delegate.schedule_event(:start, self.retry_after) if can_retry?

            @timeline.clear

            # This will prevent a transition from happening in the process state_machine.
            throw :halt
          end
        end
      end
    end
  end
end
