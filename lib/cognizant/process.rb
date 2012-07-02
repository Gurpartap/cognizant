require 'state_machine'

require "cognizant/process/pid"
require "cognizant/process/ps"
require "cognizant/process/attributes"
require "cognizant/process/actions"
require "cognizant/system/exec"

module Cognizant
  class Process
    include Cognizant::Logging
    include Cognizant::Process::PID
    include Cognizant::Process::Status
    include Cognizant::Process::Attributes
    include Cognizant::Process::Actions

    # The number of ticks to skip. Employed when starting, stopping or
    # restarting for the timeout grace period.
    # @private
    attr_accessor :ticks_to_skip

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
        transition :stopped    => :starting,  :if     => Proc.new { |p| p.autostart and not p.process_running? }

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

      event :unmonitor do
        transition any => :unmonitored
      end

      event :restart do
        transition [:running, :stopped] => :restarting
      end

      after_transition any => :starting,   :do => :start_process
      after_transition any => :stopping,   :do => :stop_process
      after_transition any => :restarting, :do => :restart_process

      before_transition any => any, :do => :record_transition_start
      after_transition  any => any, :do => :record_transition_end
    end

    def initialize(options)
      options.each do |attribute_name, value|
        # Do not accept non configurable attributes.
        unless [:ticks_to_skip].include?(attribute_name)
          self.send("#{attribute_name}=", value) if self.respond_to?("#{attribute_name}=")
        end
      end

      self.ticks_to_skip = 0

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
      print "changing state from `#{state}`"
    end

    def record_transition_end
      puts " to `#{state}`"
    end

    def process_running?
      @process_running = begin
        # Do not assume change when we're giving time to an execution by skipping ticks.
        if self.ticks_to_skip > 0
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

    private

    def skip_ticks_for(skips)
      # Accept negative skips resulting >= 0.
      self.ticks_to_skip = [self.ticks_to_skip + (skips.to_i + 1), 0].max # +1 so that we don't have to >= and ensure 0 in "skip_tick?".
    end

    def skip_tick?
      (self.ticks_to_skip -= 1) > 0 if self.ticks_to_skip > 0
    end

    def run_options(overrides = {})
      options = {}
      # CONFIGURABLE_ATTRIBUTES.each do |o|
      #   options[o] = self.send(o)
      # end
      options.merge(overrides)
    end

    def run(command, overrides = {})
      options = {}
      options = run_options({ daemonize: false }.merge(overrides)) if overrides
      System::Execute.command(command, options)
    end
  end
end
