require "state_machine"

module Cognizant
  class Process
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

    private

    def skip_tick?
      (@ticks_to_skip -= 1) > 0 if @ticks_to_skip > 0
    end

    def notify_triggers(transition)
      @triggers.each { |trigger| trigger.notify(transition) }
    end

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
  end
end
