module Cognizant
  class Process
    module Conditions
      class TriggerCondition
        attr_accessor :process, :mutex, :scheduled_events

        def initialize(process, options = {})
          self.process = process
          self.mutex = Mutex.new
          self.scheduled_events = []
        end

        def reset!
          self.cancel_all_events
        end

        def notify(transition)
          raise "Implement in subclass"
        end

        def dispatch!(event)
          self.process.dispatch!(event, self.class.name.split("::").last)
        end

        def schedule_event(event, delay)
          # TODO: Maybe wrap this in a ScheduledEvent class with methods like cancel.
          thread = Thread.new(self) do |trigger|
            begin
              sleep delay.to_f
              trigger.dispatch!(event)
              trigger.mutex.synchronize do
                trigger.scheduled_events.delete_if { |_, thread| thread == Thread.current }
              end
            rescue StandardError => e
              puts(e)
              puts(e.backtrace.join("\n"))
            end
          end

          self.scheduled_events.push([event, thread])
        end

        def cancel_all_events
          puts "Canceling all scheduled events"
          self.mutex.synchronize do
            self.scheduled_events.each {|_, thread| thread.kill}
          end
        end
      end
    end
  end
end
