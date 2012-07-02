require 'state_machine'

require "cognizant/system/exec"
require "cognizant/system/pid"
require "cognizant/system/ps"

require "cognizant/process/attributes"

module Cognizant
  class Process
    include Cognizant::Logging
    include Cognizant::System::PID
    include Cognizant::System::ProcessStatus
    include Cognizant::Process::Attributes

    # The number of ticks to skip. Employed when starting, stopping or
    # restarting for the timeout grace period.
    # @private
    attr_accessor :ticks_to_skip

    state_machine :initial => :unmonitored do
      # These are the idle states, i.e. only an event (either external or internal) will trigger a transition.
      # The distinction between stopped and unmonitored is that stopped
      # means we know it is not running and unmonitored is that we don't care if it's running.
      state :unmonitored, :started, :stopped

      # These are transitionary states, we expect the process to change state after a certain period of time.
      state :starting, :stopping, :restarting

      event :tick do
        transition :starting   => :started,   :if     => :process_running?
        transition :starting   => :stopped,   :unless => :process_running?

        transition :started    => :stopped,   :unless => :process_running?

        # The process failed to die after entering the stopping state. Change the state to reflect reality.
        transition :stopping   => :started,   :if     => :process_running?
        transition :stopping   => :stopped,   :unless => :process_running?

        transition :stopped    => :started,   :if     => :process_running?
        transition :stopped    => :starting,  :if     => :autostart?

        transition :restarting => :started,   :if     => :process_running?
        transition :restarting => :stopped,   :unless => :process_running?
      end

      event :monitor do
        transition :unmonitored => :stopped
      end

      event :start do
        transition [:unmonitored, :stopped] => :starting
      end

      event :stop do
        transition :started => :stopping
      end

      event :unmonitor do
        transition any => :unmonitored
      end

      event :restart do
        transition [:started, :stopped] => :restarting
      end

      after_transition any => :starting,   :do => :start_process
      after_transition any => :stopping,   :do => :stop_process
      after_transition any => :restarting, :do => :restart_process

      before_transition any => any, :do => :record_transition_start
      after_transition any => any,  :do => :record_transition_end
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

    def process_running?
      @process_running = begin
        # Do not assume change when we're giving time to an execution by skipping ticks.
        if self.ticks_to_skip > 0
          @process_running
        # elsif self.ping_command and run(self.ping_command).succeeded
        #   true
        elsif pid_running?
          true
        else
          false
        end
      end
    end

    def autostart?
      self.autostart and not process_running?
    end

    def pidfile
      @pidfile = @pidfile || default_pid_file
    end

    def record_transition_start
      print "changing state from `#{state}`"
    end

    def record_transition_end
      puts " to `#{state}`"
    end

    def tick
      print "."
      return puts "(skip tick)" if skip_tick?
      @action_thread.kill if @action_thread # TODO: Ensure if this is really needed.
      super
    end

    def start_process
      result_handler = Proc.new do |result|
        if result.respond_to?(:succeeded) and result.succeeded
          write_pid(result.pid) if result.pid != 0
        end
      end
      execute_action(
        result_handler,
        daemonize: self.daemonize,
        # env:       (self.env || {}).merge(self.start_env || {}),
        # before:    self.start_before_command,
        command:   self.start_command,
        # after:     self.start_after_command,
        timeout:   self.start_timeout
      )
    end

    def stop_process
      result_handler = Proc.new do |result|
        # If it is a boolean and value is true OR if it's an execution result and it succeeded.
        if (!!result == result and result) or (result.respond_to?(:succeeded) and result.succeeded)
          unlink_pid unless pid_running?
        end
      end
      execute_action(
        result_handler,
        # env:     (self.env || {}).merge(self.stop_env || {}),
        # before:  self.stop_before_command,
        command: self.stop_command,
        signals: self.stop_signals,
        # after:   self.stop_after_command,
        timeout: self.stop_timeout
      )
    end

    def restart_process
      result_handler = Proc.new do |result|
        # If it is a boolean and value is true OR if it's an execution result and it succeeded.
        if (!!result == result and result) or (result.respond_to?(:succeeded) and result.succeeded)
          unlink_pid unless pid_running?
        end
      end
      execute_action(
        result_handler,
        # env:     (self.env || {}).merge(self.restart_env || {}),
        # before:  self.restart_before_command,
        command: self.restart_command,
        signals: self.restart_signals,
        # after:   self.restart_after_command,
        timeout: self.restart_timeout
      )
    end

    private

    def default_pid_file
      ""
    end

    def skip_ticks_for(seconds)
      # 1 second = 1 skip
      # We can optionally accept negative skip seconds totalling >= 0.
      self.ticks_to_skip = [self.ticks_to_skip + (seconds.to_i + 1), 0].max # +1 so that we don't have to >= and ensure 0 in skip_tick?
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

    def execute_action(result_handler, options)
      daemonize      = options[:daemonize] || false
      env            = options[:env]
      before_command = options[:before]
      command        = options[:command]
      after_command  = options[:after]
      signals        = options[:signals]
      timeout        = options[:timeout] || 10

      # TODO: Works well but can some refactoring make it more declarative?
      @action_thread = Thread.new do
        result = false
        queue = Queue.new
        thread = Thread.new do
          if before_command and not success = run(before_command).succeeded
            queue.push(success)
            Thread.exit
          end

          if (command and success = run(command, { daemonize: daemonize, env: env }) and success.succeeded)
            run(after_command) if after_command
            queue.push(success)
            Thread.exit
          end

          # If the caller has attempted to set signals, then it can handle it's result.
          if (options.has_key?(:signals) and success = stop_with_signals(signals: signals, timeout: timeout))
            run(after_command) if after_command
            queue.push(success)
            Thread.exit
          end

          queue.push(false)
          Thread.exit
        end

        timeout_left = timeout + 1
        while (timeout_left -= 1) > 0 do
          # If there is something in the queue, we have the required result. Simpler than Mutex#synchronize.
          if result = queue.pop
            # Rollback the pending skips, since we finished before timeout.
            skip_ticks_for(-timeout_left)
            break
          end
          sleep 1
        end
        
        # Kill the nested thread.
        thread.kill

        # Action callback.
        result_handler.call(result) if result_handler.respond_to?(:call)

        # Kill self.
        Thread.kill
      end

      # We skip so that we're not reinformed about the required transition by the tick.
      skip_ticks_for(timeout)
    end
  end
end
