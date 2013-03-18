require "monitor"
require "thread"

require "cognizant/process/state_machine"
require "cognizant/process/dsl_proxy"
require "cognizant/process/pid"
require "cognizant/process/status"
require "cognizant/process/execution"
require "cognizant/process/attributes"
require "cognizant/process/actions"
require "cognizant/process/conditions"
require "cognizant/process/condition_delegate"
require "cognizant/process/triggers"
require "cognizant/process/trigger_delegate"
require "cognizant/process/children"
require "cognizant/util/transform_hash_keys"

module Cognizant
  class Process
    include Cognizant::Process::PID
    include Cognizant::Process::Status
    include Cognizant::Process::Execution
    include Cognizant::Process::Attributes
    include Cognizant::Process::Actions
    include Cognizant::Process::Children

    def initialize(process_name = nil, attributes = {}, &block)
      reset!

      @name = process_name.to_s if process_name

      set_attributes(attributes)

      if block
        if block.arity == 0
          dsl_proxy = Cognizant::Process::DSLProxy.new(self, &block)
          set_attributes(dsl_proxy.attributes)
        else
          instance_exec(self, &block)
        end
      end

      raise "Process name is missing. Aborting." unless self.name
      Log[self].info "Loading process #{self.name}..."

      initialize_state_machines
    end

    def reset!
      reset_attributes!

      @application = nil
      @ticks_to_skip = 0
      @conditions = []
      @triggers = []
      @children = []
      @action_mutex = Monitor.new
      @monitor_children = false
    end

    def check(check_name, options, &block)
      if klass = Cognizant::Process::Conditions[check_name]
        @conditions << ConditionDelegate.new(check_name, options.deep_symbolize_keys!, &block)
      elsif klass = Cognizant::Process::Triggers[check_name]
        @triggers << TriggerDelegate.new(check_name, self, options.deep_symbolize_keys!, &block)
      end
    end

    def monitor_children(child_process_attributes = {}, &child_process_block)
      @monitor_children = true
      @child_process_attributes, @child_process_block = child_process_attributes, child_process_block
    end

    def pidfile
      @pidfile || File.join(@application.pids_dir, @name + '.pid')
    end

    def logfile
      @logfile || File.join(@application.logs_dir, @name + '.log')
    end

    def last_transition_time
      @last_transition_time || 0
    end

    def handle_user_command(command)
      # When the user issues a command, reset any
      # triggers so that scheduled events gets cleared.
      @triggers.each { |trigger| trigger.reset! }
      dispatch!(command, "user initiated")
    end

    def dispatch!(action, reason = nil)
      @action_mutex.synchronize do
        if action.respond_to?(:call)
          action.call(self)
        else
          self.send("#{action}")
        end
      end
    end

    private

    def set_attributes(attributes)
      if attributes.has_key?(:checks) and attributes[:checks].kind_of?(Hash)
        attributes[:checks].each do |check_name, args, &block|
          check(check_name, args, &block)
        end
      end
      attributes.delete(:checks)

      if attributes.has_key?(:monitor_children) and attributes[:monitor_children].kind_of?(Hash)
        monitor_children(attributes[:monitor_children])
      end

      attributes.each do |attribute_name, value|
        self.send("#{attribute_name}=", value) if self.respond_to?("#{attribute_name}=")
      end
    end

    def run(command, action_overrides = {})
      options = { daemonize: false }
      # Options from daemon config.
      [:uid, :gid, :groups, :chroot, :chdir, :umask].each do |attribute|
        options[attribute] = self.send(attribute)
      end
      execute(command, options.merge(action_overrides))
    end

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
  end
end
