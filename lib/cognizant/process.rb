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
require "cognizant/util/symbolize_hash_keys"

module Cognizant
  class Process
    include Cognizant::Process::PID
    include Cognizant::Process::Status
    include Cognizant::Process::Execution
    include Cognizant::Process::Attributes
    include Cognizant::Process::Actions

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

      before_transition any      => :starting,   :do => lambda { |p| p.autostart = true }
      after_transition  any      => :starting,   :do => :start_process

      before_transition :running => :stopping,   :do => lambda { |p| p.autostart = false }
      after_transition  any      => :stopping,   :do => :stop_process

      before_transition any      => :restarting, :do => lambda { |p| p.autostart = true }
      after_transition  any      => :restarting, :do => :restart_process

      before_transition any => any, :do => :notify_triggers
      after_transition  any => any, :do => :record_transition
    end

    def initialize(process_name = nil, attributes = {}, &block)
      @ticks_to_skip = 0
      @conditions = []
      @triggers = []
      @children = []
      @action_mutex = Monitor.new
      @monitor_children =  false
      @autostart = true
      
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

      # Let state_machine initialize as well.
      initialize_state_machines
    end

    def monitor_children(child_process_attributes = {}, &child_process_block)
      @monitor_children = true
      @child_process_attributes, @child_process_block = child_process_attributes, child_process_block
    end

    def check(check_name, options, &block)
      if klass = Cognizant::Process::Conditions[check_name]
        @conditions << ConditionDelegate.new(check_name, options.deep_symbolize_keys!, &block)
      elsif klass = Cognizant::Process::Triggers[check_name]
        @triggers << TriggerDelegate.new(check_name, self, options.deep_symbolize_keys!)
      end
    end

    def tick
      return if skip_tick?
      @action_thread.kill if @action_thread # TODO: Ensure if this is really needed.

      # Invoke the state_machine event.
      super

      if running?
        run_conditions

        if @monitor_children
          refresh_children!
          @children.each(&:tick)
        end
      end
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

    def process_running?
      @process_running = begin
        # Do not assume change when we're giving time to an execution by skipping ticks.
        if @ticks_to_skip > 0
          @process_running
        elsif @ping_command and run(@ping_command).succeeded?
          true
        elsif pid_running?
          true
        else
          false
        end
      end
    end

    def pidfile
      @pidfile || File.join(Cognizant::Daemon.pids_dir, @name + '.pid')
    end

    def logfile
      @logfile || File.join(Cognizant::Daemon.logs_dir, @name + '.log')
    end

    def last_transition_time
      @last_transition_time || 0
    end

    private

    def record_transition(transition)
      unless transition.loopback?
        @transitioned = true
        @last_transition_time = Time.now.to_i

        # When a process changes state, we should clear the memory of all the conditions.
        @conditions.each { |condition| condition.clear_history! }
        puts "#{name} changing from #{transition.from_name} => #{transition.to_name}"

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

    def skip_ticks_for(skips)
      # Accept negative skips with the result being >= 0.
      @ticks_to_skip = [@ticks_to_skip + (skips.to_i + 1), 0].max # +1 so that we don't have to >= and ensure 0 in "skip_tick?".
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

      threads.inject([]) do |actions, (condition, thread)|
        thread.join
        if thread[:actions].size > 0
          puts "#{condition.name} dispatched: #{thread[:actions].join(',')}"
          thread[:actions].each do |action|
            actions << [action, condition.to_s]
          end
        end
        actions
      end.each do |(action, reason)|
        break if @transitioned
        dispatch!(action, reason)
      end
    end

    def notify_triggers(transition)
      @triggers.each { |trigger| trigger.notify(transition) }
    end

    def refresh_children!
      # First prune the list of dead children.
      @children.delete_if do |child|
        !child.process_running?
      end

      # Add new found children to the list.
      new_children_pids = Cognizant::System.get_children(@process_pid) - @children.map { |child| child.cached_pid }

      unless new_children_pids.empty?
        Cognizant.log.info "Existing children: #{@children.collect{ |c| c.cached_pid }.join(",")}. Got new children: #{new_children_pids.inspect} for #{@process_pid}."
      end

      # Construct a new process wrapper for each new found children.
      new_children_pids.each do |child_pid|
        name = "<child(pid:#{child_pid})>"
        attributes = @child_process_attributes.merge({ name: name, autostart: false }) # We do not have control over child process' lifecycle, so avoid even attempting to maintain its state.

        child = Cognizant::Process.new(nil, attributes, &@child_process_block)
        child.write_pid(child_pid)
        @children << child
        child.monitor
      end
    end
  end
end
