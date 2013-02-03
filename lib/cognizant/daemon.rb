require "eventmachine"

require "cognizant"
require "cognizant/log"
require "cognizant/process"
require "cognizant/application"
require "cognizant/system"

module Cognizant
  class Daemon
    # Whether or not to the daemon in the background.
    # @return [true, false] Defaults to true
    attr_accessor :daemonize

    attr_accessor :sockfile

    # The pid lock file for the daemon.
    # e.g. /Users/Gurpartap/.cognizant/cognizantd.pid
    # @return [String] Defaults to /var/run/cognizant/cognizantd.pid
    attr_accessor :pidfile

    # The file to log the daemon's operations information into.
    # e.g. /Users/Gurpartap/.cognizant/cognizantd.log
    # @return [String] Defaults to /var/log/cognizant/cognizantd.log
    attr_accessor :logfile

    # Whether or not to log to syslog daemon instead of file.
    # @return [true, false] Defaults to true
    attr_accessor :syslog

    # The level of information to log. This does not affect the log
    # level of managed processes.
    # @note The possible values must be one of the following:
    #   DEBUG, INFO, WARN, ERROR and FATAL or 0, 1, 2, 3, 4 (respectively).
    # @return [Logger::Severity] Defaults to Logger::INFO
    attr_accessor :loglevel

    # Hash of applications being managed.
    # @private
    # @return [Hash]
    attr_accessor :applications

    # @private
    attr_accessor :socket

    def load(options = {})
      self.reset!

      files = []
      apps = {}

      files = options.delete(:load) if options.has_key?(:load)
      apps = options.delete(:applications) if options.has_key?(:applications)

      # Attributes.
      options.each do |key, value|
        self.send("#{key}=", options.delete(key)) if self.respond_to?("#{key}=")
      end

      self.sockfile = File.expand_path(self.sockfile)
      self.pidfile  = File.expand_path(self.pidfile)
      self.logfile  = File.expand_path(self.logfile)

      Log[self].info "Booting up Cognizant daemon..."
      setup_directories
      setup_logging
      stop_previous_daemon
      stop_previous_socket
      trap_signals
      daemonize_process
      write_pid

      EventMachine.run do
        # Applications.
        Log[self].info "Cognizant daemon running successfully."
        apps.each do |key, value|
          self.create_application(key, value)
        end

        [*files].each do |file|
          load_file(file)
        end

        EventMachine.start_unix_domain_server(self.sockfile, Cognizant::Interface)

        EventMachine.add_periodic_timer(1) do
          Cognizant::System.reset_data!
          self.applications.values.each(&:tick)
        end
      end
    end

    def load_file(file)
      file = File.expand_path(file)
      Log[self].info "Loading config from #{file}..."
      Kernel.load(file) if File.exists?(file)
    end

    def reset!
      self.daemonize    = true
      self.sockfile     = "/var/run/cognizant/cognizantd.sock"
      self.pidfile      = "/var/run/cognizant/cognizantd.pid"
      self.syslog       = false
      self.logfile      = "/var/log/cognizant/cognizantd.log"
      self.loglevel     = Logging::LEVELS["INFO"]
      self.applications.values.each(&:reset!) if self.applications.is_a?(Hash)
      self.applications = {}
    end

    def create_application(name, options = {}, &block)
      app = Cognizant::Application.new(name, options, &block)
      self.applications[app.name.to_sym] = app
      app
    end

    def setup_logging
      Cognizant::Log.logger.root.level = self.loglevel

      unless self.daemonize
        stdout_appender = Cognizant::Log.stdout
        Cognizant::Log.logger.root.add_appenders(stdout_appender)
      end

      if self.syslog
        # TODO: Choose a non-default facility? (default: LOG_USR).
        syslog_appender = Cognizant::Log.syslog("cognizantd")
        Cognizant::Log.logger.root.add_appenders(syslog_appender)
      elsif self.logfile
        logfile_appender = Cognizant::Log.file(self.logfile)
        Cognizant::Log.logger.root.add_appenders(logfile_appender)
      end
    end

    def setup_directories
      # Create the require directories.
      System.mkdir(File.dirname(self.sockfile), File.dirname(self.pidfile), File.dirname(self.logfile))
    end

    # Stops the socket server and the tick loop, and performs cleanup.
    def shutdown!
      Log[self].info "Shutting down Cognizant daemon..."
      EventMachine.next_tick do
        EventMachine.stop
        self.applications.values.each(&:shutdown!)
        unlink_pid
        # TODO: Close logger?
      end
    end

    def trap_signals
      terminator = Proc.new do
        Log[self].info "Received signal to shutdown."
        shutdown!
      end

      Signal.trap('TERM', &terminator)
      Signal.trap('INT',  &terminator)
      Signal.trap('QUIT', &terminator)
    end

    def stop_previous_daemon
      if self.pidfile and File.exists?(self.pidfile)
        if previous_daemon_pid = File.read(self.pidfile).to_i
          # Only attempt to stop automatically if the daemon will run in background.
          if self.daemonize and Cognizant::System.pid_running?(previous_daemon_pid)
            # Ensure that the process stops within 5 seconds or force kill.
            signals = ["TERM", "KILL"]
            timeout = 2
            catch :stopped do
              signals.each do |stop_signal|
                # Send the stop signal and wait for it to stop.
                Cognizant::System.signal(stop_signal, previous_daemon_pid)

                # Poll to see if it's stopped yet. Minimum 2 so that we check at least once again.
                ([timeout / signals.size, 2].max).times do
                  throw :stopped unless Cognizant::System.pid_running?(previous_daemon_pid)
                  sleep 1
                end
              end
            end
          end
        end

        # Alert the user to manually stop the previous daemon, if it is [still] alive.
        if Cognizant::System.pid_running?(previous_daemon_pid)
          raise "There is already a daemon running with pid #{previous_daemon_pid}."
        else
          unlink_pid # This will be overwritten anyways.
        end
      end
    end

    def stop_previous_socket
      # Socket isn't actually owned by anyone.
      begin
        sock = UNIXSocket.new(self.sockfile)
      rescue Errno::ECONNREFUSED
        # This happens with non-socket files and when the listening
        # end of a socket has exited.
      rescue Errno::ENOENT
        # Socket doesn't exist.
        return
      else
        # Rats, it's still active.
        sock.close
        raise Errno::EADDRINUSE.new("Another process or application is likely already listening on the socket at #{self.sockfile}.")
      end
    
      # Socket should still exist, so don't need to handle error.
      stat = File.stat(self.sockfile)
      unless stat.socket?
        raise Errno::EADDRINUSE.new("Non-socket file present at socket file path #{self.sockfile}. Either remove that file and restart Cognizant, or change the socket file path.")
      end
    
      Log[self].info("Blowing away old socket file at #{self.sockfile}. This likely indicates a previous Cognizant application which did not shutdown gracefully.")

      # Whee, blow it away.
      unlink_sockfile
    end

    # Daemonize the current process and save it pid in a file.
    def daemonize_process
      if self.daemonize
        Log[self].info "Daemonizing into the background..."
        ::Process.daemon
      end
    end

    def write_pid
      pid = ::Process.pid
      if self.pidfile
        Log[self].info "Writing the daemon pid (#{pid}) to the pidfile..."
        File.open(self.pidfile, "w") { |f| f.write(pid) }
      end
    end

    def unlink_pid
      Cognizant::System.unlink_file(self.pidfile) if self.pidfile
    end

    def unlink_sockfile
      Cognizant::System.unlink_file(self.sockfile) if self.sockfile
    end
  end
end
