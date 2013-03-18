require "cognizant/process/conditions/poll_condition"

Dir["#{File.dirname(__FILE__)}/conditions/*.rb"].each do |condition|
  require condition
end

module Cognizant
  class Process
    def check(check_name, options, &block)
      if klass = Cognizant::Process::Conditions[check_name]
        @conditions << ConditionDelegate.new(check_name, options.deep_symbolize_keys!, &block)
      elsif klass = Cognizant::Process::Triggers[check_name]
        @triggers << TriggerDelegate.new(check_name, self, options.deep_symbolize_keys!, &block)
      end
    end

    private

    def run_conditions
      now = Time.now.to_i

      threads = @conditions.collect do |condition|
        [condition, Thread.new { Thread.current[:actions] = condition.run(cached_pid, now) }]
      end

      @transitioned = false

      collect_conditions_actions(threads).each do |(action, reason)|
        break if @transitioned
        dispatch!(action, reason)
      end
    end

    def collect_conditions_actions(threads)
      threads.inject([]) do |actions, (condition, thread)|
        thread.join
        thread[:actions].each do |action|
          action_name = action.respond_to?(:call) ? "call to custom block" : action
          Log[self].debug "Dispatching #{action_name} to #{name} for #{condition.to_s}."
          actions << [action, condition.to_s]
        end
        actions
      end
    end

    module Conditions
      def self.[](name)
        begin
          const_get(name.to_s.camelcase)
        rescue NameError
          nil
        end
      end
    end
  end
end
