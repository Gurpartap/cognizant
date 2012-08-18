require 'state_machine'

require "cognizant/process/pid"
require "cognizant/process/status"
require "cognizant/process/execution"
require "cognizant/process/attributes"
require "cognizant/process/actions"

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

      after_transition  any      => :starting,   :do => :start_process
      before_transition :running => :stopping,   :do => lambda { |p| p.autostart = false }
      after_transition  any      => :stopping,   :do => :stop_process
      before_transition any      => :restarting, :do => lambda { |p| p.autostart = true }
      after_transition  any      => :restarting, :do => :restart_process

      before_transition any => any, :do => :record_transition_start
      after_transition  any => any, :do => :record_transition_end
    end

    def initialize(options)
      # Default.
      self.autostart = true

      options.each do |attribute_name, value|
        self.send("#{attribute_name}=", value) if self.respond_to?("#{attribute_name}=")
      end

      @ticks_to_skip = 0

      # Let state_machine initialize as well.
      super
    end

    def tick
      return if skip_tick?
      @action_thread.kill if @action_thread # TODO: Ensure if this is really needed.

      # Invoke the state_machine event.
      super
    end

    def record_transition_start
      print "#{name}: changing state from `#{state}`"
    end

    def record_transition_end
      puts " to `#{state}`"
    end

    def process_running?
      @process_running = begin
        # Do not assume change when we're giving time to an execution by skipping ticks.
        if @ticks_to_skip > 0
          @process_running
        elsif self.ping_command and run(self.ping_command).succeeded?
          true
        elsif pid_running?
          true
        else
          false
        end
      end
    end

    def pidfile
      @pidfile = @pidfile || File.join(Cognizant::Server.daemon.pids_dir, self.name + '.pid')
    end

    def logfile
      @logfile = @logfile || File.join(Cognizant::Server.daemon.logs_dir, self.name + '.log')
    end

    private

    def skip_ticks_for(skips)
      # Accept negative skips with the result being >= 0.
      @ticks_to_skip = [@ticks_to_skip + (skips.to_i + 1), 0].max # +1 so that we don't have to >= and ensure 0 in "skip_tick?".
    end

    def skip_tick?
      (@ticks_to_skip -= 1) > 0 if @ticks_to_skip > 0
    end

    def run(command, overrides = {})
      options = { daemonize: false }
      [:uid, :gid, :groups, :chroot, :chdir, :umask].each do |attribute|
        options[attribute] = self.send(attribute)
      end
      execute(command, options.merge(overrides))
    end
  end
end
