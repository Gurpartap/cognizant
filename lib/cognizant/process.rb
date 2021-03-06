require "monitor"
require "thread"

require "state_machine"

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

    state_machine :initial => :unmonitored do
      # These are the idle states, i.e. only an event (either external or internal) will trigger a transition.
      # The distinction between stopped and unmonitored is that stopped
      # means we know it is not running and unmonitored is that we don't care if it's running.
      state :unmonitored, :running, :stopped

      # These are transitionary states, we expect the process to change state after a certain period of time.
      state :starting, :stopping, :restarting

      event :tick do
        transition :starting   => :running,   :if     => :process_running?
        transition :starting   => :stopped,   :unless => :process_running?

        transition :running    => :stopped,   :unless => :process_running?

        # The process failed to die after entering the stopping state. Change the state to reflect reality.
        transition :stopping   => :running,   :if     => :process_running?
        transition :stopping   => :stopped,   :unless => :process_running?

        transition :stopped    => :running,   :if     => :process_running?
        transition :stopped    => :starting,  :if     => lambda { |p| p.autostart and not p.process_running? }

        transition :restarting => :running,   :if     => :process_running?
        transition :restarting => :stopped,   :unless => :process_running?
      end

      event :monitor do
        transition :unmonitored => :stopped
      end

      event :start do
        transition [:unmonitored, :stopped] => :starting
      end

      event :stop do
        transition :running => :stopping
      end

      event :restart do
        transition [:running, :stopped] => :restarting
      end

      event :unmonitor do
        transition any => :unmonitored
      end

      before_transition any      => :starting,    :do => lambda { |p| p.autostart = true }
      after_transition  any      => :starting,    :do => :start_process

      before_transition any      => :stopping,    :do => lambda { |p| p.autostart = false }
      after_transition  :running => :stopping,    :do => :stop_process

      before_transition any      => :restarting,  :do => lambda { |p| p.autostart = true }
      after_transition  any      => :restarting,  :do => :restart_process

      before_transition any      => :unmonitored, :do => lambda { |p| p.autostart = false }

      before_transition any => any, :do => :notify_triggers
      after_transition  any => any, :do => :record_transition
    end

    def initialize(process_name = nil, attributes = {}, &block)
      reset!

      @name = process_name.to_s if process_name

      set_attributes(attributes)

      handle_initialize_block(&block) if block

      raise "Process name is missing. Aborting." unless self.name
      Log[self].info "Loading process #{self.name}..."

      # Let state_machine initialize as well.
      initialize_state_machines
    end

    def handle_initialize_block(&block)
      if block.arity == 0
        attributes = Cognizant::Process::DSLProxy.new(self, &block).attributes
        set_attributes(attributes)
      else
        instance_exec(self, &block)
      end
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

    def tick
      return if skip_tick?
      @action_thread.kill if @action_thread # TODO: Ensure if this is really needed.

      # Invoke the state_machine event.
      super

      if self.running? # State method.
        run_conditions

        if @monitor_children
          refresh_children!
          @children.each(&:tick)
        end
      end
    end

    def skip_ticks_for(skips)
      # Accept negative skips with the result being >= 0.
      # +1 so that we don't have to >= and ensure 0 in #skip_tick?.
      @ticks_to_skip = [@ticks_to_skip + (skips.to_i + 1), 0].max
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

    def record_transition(transition)
      unless transition.loopback?
        @transitioned = true
        @last_transition_time = Time.now.to_i

        # When a process changes state, we should clear the memory of all the conditions.
        @conditions.each { |condition| condition.clear_history! }
        Log[self].debug "Changing state of #{name} from #{transition.from_name} => #{transition.to_name}"

        # And we should re-populate its child list.
        if @monitor_children
          @children.clear
        end

        # Update the pid from pidfile, since the state of process changed, if the process is managing it's own pidfile.
        read_pid if @pidfile
      end
    end

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

    def skip_tick?
      (@ticks_to_skip -= 1) > 0 if @ticks_to_skip > 0
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
          Log[self].debug "Dispatching #{action_name} to #{name} for #{condition.to_s.strip}."
          actions << [action, condition.to_s]
        end
        actions
      end
    end

    def notify_triggers(transition)
      @triggers.each { |trigger| trigger.notify(transition) }
    end
  end
end
