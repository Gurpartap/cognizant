require "eventmachine"

require "cognizant"
require "cognizant/logging"
require "cognizant/process"
require "cognizant/interface"
require "cognizant/system"

module Cognizant
  module Daemon
    extend self

    # Whether or not to the daemon in the background.
    # @return [true, false] Defaults to true
    attr_accessor :daemonize

    # The pid lock file for the daemon.
    # e.g. /Users/Gurpartap/.cognizant/cognizantd.pid
    # @return [String] Defaults to /var/run/cognizant/cognizantd.pid
    attr_accessor :pidfile

    # The file to log the daemon's operations information into.
    # e.g. /Users/Gurpartap/.cognizant/cognizantd.log
    # @return [String] Defaults to /var/log/cognizant/cognizantd.log
    attr_accessor :logfile

    # The level of information to log. This does not affect the log
    # level of managed processes.
    # @note The possible values must be one of the following:
    #   Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR and
    #   Logger::FATAL or 0, 1, 2, 3, 4 (respectively).
    # @return [Logger::Severity] Defaults to Logger::INFO
    attr_accessor :loglevel

    # The socket lock file for the server. This file is ignored if valid
    # bind address and port are given.
    # e.g. /Users/Gurpartap/.cognizant/cognizant-server.sock
    # @return [String] Defaults to /var/run/cognizant/cognizantd.sock
    attr_accessor :socket

    # The TCP address and port to start the server with. e.g. 8081,
    # "127.0.0.1:8081", "0.0.0.0:8081".
    # @return [String] Defaults to nil
    attr_accessor :port

    # Username for securing server access. e.g. "cognizant-user"
    # @return [String] Defaults to nil
    attr_accessor :username

    # Password to accompany the username.
    # e.g. "areallyverylongpasswordbecauseitmatters"
    # @return [String] Defaults to nil
    attr_accessor :password

    # Directory to store the pid files of managed processes, when required.
    # e.g. /Users/Gurpartap/.cognizant/pids/
    # @return [String] Defaults to /var/run/cognizant/pids/
    attr_accessor :pids_dir

    # Directory to store the log files of managed processes, when required.
    # e.g. /Users/Gurpartap/.cognizant/logs/
    # @return [String] Defaults to /var/log/cognizant/logs/
    attr_accessor :logs_dir

    # Environment variables for managed processes to inherit.
    # @return [Hash] Defaults to {}
    attr_accessor :env

    # The current working directory for the managed processes to start with.
    # @return [String] Defaults to nil
    attr_accessor :chdir

    # Limit the permission modes for files and directories created by the
    # daemon and the managed processes.
    # @return [Integer] Defaults to nil
    attr_accessor :umask

    # Run the daemon and managed processes as the given user.
    # e.g. "deploy", 1000
    # @return [String] Defaults to nil
    attr_accessor :user

    # Run the daemon and managed processes as the given user group.
    # e.g. "deploy"
    # @return [String] Defaults to nil
    attr_accessor :group

    # Hash of processes being managed.
    # @private
    # @return [Hash]
    attr_accessor :processes

    # Initializes and starts the cognizant daemon with the given options
    # as instance attributes.
    # @param [Hash] options A hash of instance attributes and their values.
    def init(options = {})
      # Daemon config.
      @daemonize = options.has_key?(:daemonize) ? options[:daemonize] : true
      @pidfile   = options[:pidfile]       || "/var/run/cognizant/cognizantd.pid"
      @logfile   = options[:logfile]       || "/var/log/cognizant/cognizantd.log"
      @loglevel  = options[:loglevel].to_i || Logger::INFO
      @socket    = options[:socket]        || "/var/run/cognizant/cognizantd.sock"
      @port      = options[:port]          || nil
      @username  = options[:username]      || nil
      @password  = options[:password]      || nil
      @trace     = options[:trace]         || nil

      # Processes config.                            
      @pids_dir = options[:pids_dir] || "/var/run/cognizant/pids/"
      @logs_dir = options[:logs_dir] || "/var/log/cognizant/logs/"
      @env      = options[:env]      || {}
      @chdir    = options[:chdir]    || nil
      @umask    = options[:umask]    || nil
      @user     = options[:user]     || nil
      @group    = options[:group]    || nil

      # Expand paths.
      @socket   = File.expand_path(@socket)
      @pidfile  = File.expand_path(@pidfile)
      @logfile  = File.expand_path(@logfile)
      @pids_dir = File.expand_path(@pids_dir)
      @logs_dir = File.expand_path(@logs_dir)

      @processes = Hash.new
      @processes_to_load = []

      # Only available through a config file/stdin.
      @processes_to_load = options[:monitor] if options.has_key?(:monitor)
    end

    def bootup
      setup_logging

      stop_previous_daemon
      stop_previous_socket

      setup_directories
      trap_signals
      Cognizant.log.info "Booting up cognizantd..."
      EventMachine.run do
        start_interface_socket
        start_periodic_ticks
        daemonize_process
        write_pid
        load_processes(@processes_to_load) and @processes_to_load = nil
      end
    end

    def load(config_file)
      config_file = File.expand_path(config_file)
      Cognizant.log.info "Loading config from #{config_file}..."
      # config = YAML.load_file(config_file)
      # config = config.inject({}) { |c,(k,v)| c[k.gsub("-", "_").to_sym] = v; c }
      # load_processes(config[:monitor]) if config.has_key?(:monitor)
      Kernel.load(config_file)
    end

    def monitor(process_name = nil, attributes = {}, &block)
      process = Cognizant::Process.new(process_name, attributes, &block)
      @processes[process.name] = process
      process.monitor
    end

    # Stops the TCP server and the tick loop, and performs cleanup.
    def shutdown
      Cognizant.log.info "Shutting down cognizantd..."
      EventMachine.next_tick do
        EventMachine.stop
        unlink_pid
        unlink_socket
        Cognizant.logger.close
      end
    end

    private

    def load_processes(processes_to_load)
      if processes_to_load
        processes_to_load.each do |name, attributes|
          monitor(name, attributes)
        end
      end
    end

    # Starts the TCP server with the set socket lock file or port.
    def start_interface_socket
      if port = @port
        Cognizant.log.info "Starting the TCP server at #{@port}..."
        host = "127.0.0.1"
        splitted = port.to_s.split(":")
        host, port = splitted if splitted.size > 1
        EventMachine.start_server(host, port, Cognizant::Interface)
      else
        Cognizant.log.info "Starting the UNIX domain server with socket #{@socket}..."
        EventMachine.start_unix_domain_server(@socket, Cognizant::Interface)
      end
    end

    # Starts the loop that defines the time window for determining and acting upon process states.
    def start_periodic_ticks
      Cognizant.log.info "Starting the periodic tick..."
      EventMachine.add_periodic_timer(1) do
        Cognizant::System.reset_data!
        @processes.values.map(&:tick)
      end
    end

    def setup_logging
      # Setup logging.
      Cognizant::Logging.add_log_adapter(File.open(@logfile, "a"))
      Cognizant::Logging.add_log_adapter($stdout) unless @daemonize
      Cognizant.log.level = if @trace then Logger::DEBUG else @loglevel end
    end

    def setup_directories
      # Create the require directories.
      [File.dirname(@pidfile), File.dirname(@logfile), @pids_dir, @logs_dir, File.dirname(@socket)].each do |directory|
        FileUtils.mkdir_p(directory)
      end
    end

    def trap_signals
      terminator = Proc.new do
        Cognizant.log.info "Received signal to shutdown."
        shutdown
      end

      Signal.trap('TERM', &terminator)
      Signal.trap('INT',  &terminator)
      Signal.trap('QUIT', &terminator)
    end

    def stop_previous_daemon
      if @pidfile and File.exists?(@pidfile)
        if previous_daemon_pid = File.read(@pidfile).to_i
          # Only attempt to stop automatically if the daemon will run in background.
          if @daemonize and Cognizant::System.pid_running?(previous_daemon_pid)
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
        sock = UNIXSocket.new(@socket)
      rescue Errno::ECONNREFUSED
        # This happens with non-socket files and when the listening
        # end of a socket has exited.
      rescue Errno::ENOENT
        # Socket doesn't exist.
        return
      else
        # Rats, it's still active.
        sock.close
        raise Errno::EADDRINUSE.new("Another process (probably another cognizantd) is listening on the Cognizant command socket at #{@socket}. If you'd like to run this cognizantd as well, pass a `-s PATH_TO_SOCKET` to change the command socket location.")
      end

      # Socket should still exist, so don't need to handle error.
      stat = File.stat(@socket)
      unless stat.socket?
        raise Errno::EADDRINUSE.new("Non-socket file present at Cognizant command socket path #{@socket}. Either remove that file and restart Cognizant, or pass a `-s PATH_TO_SOCKET` to change the command socket location.")
      end

      Cognizant.log.info("Blowing away old Cognizant command socket at #{@socket}. This likely indicates a previous Cognizant worker which exited uncleanly.")
      # Whee, blow it away.
      unlink_socket
    end

    # Daemonize the current process and save it pid in a file.
    def daemonize_process
      if @daemonize
        Cognizant.log.info "Daemonizing into the background..."
        ::Process.daemon
      end
    end

    def write_pid
      pid = ::Process.pid
      if @pidfile
        Cognizant.log.info "Writing the daemon pid (#{pid}) to the pidfile..."
        File.open(@pidfile, "w") { |f| f.write(pid) }
      end
    end

    def unlink_pid
      unlink_file(@pidfile)
    end

    def unlink_socket
      unlink_file(@socket)
    end

    def unlink_file(path)
      begin
        File.unlink(path) if path
      rescue Errno::ENOENT => e
        nil
      end
    end
  end
end
