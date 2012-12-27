require "cognizant/process/triggers"

module Cognizant
  class Process
    class TriggerDelegate
      attr_accessor :name, :process, :mutex, :scheduled_events

      def initialize(name, process, options = {})
        @name, @process = name, process
        @mutex = Mutex.new
        @scheduled_events = []

        @trigger = Cognizant::Process::Triggers[@name].new(options)
        # TODO: This is hackish even though it keeps trigger implementations simple.
        @trigger.instance_variable_set(:@delegate, self)
      end

      def notify(transition)
        @trigger.notify(transition)
      end

      def reset!
        @trigger.reset!
        self.cancel_all_events
      end

      def dispatch!(event)
        @process.dispatch!(event, @name)
      end

      def schedule_event(event, delay)
        # TODO: Maybe wrap this in a ScheduledEvent class with methods like cancel.
        thread = Thread.new(self) do |trigger|
          begin
            sleep(delay)
            trigger.dispatch!(event)
            trigger.mutex.synchronize do
              trigger.scheduled_events.delete_if { |_, thread| thread == Thread.current }
            end
          rescue StandardError => e
            puts(e)
            puts(e.backtrace.join("\n"))
          end
        end

        @scheduled_events.push([event, thread])
      end

      def cancel_all_events
        # puts "Canceling all scheduled events"
        @mutex.synchronize do
          @scheduled_events.each {|_, thread| thread.kill}
        end
      end
    end
  end
end
