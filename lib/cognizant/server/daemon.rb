require "eventmachine"

require "cognizant/logging"
require "cognizant/process"
require "cognizant/server/interface"

module Cognizant
  module Server
    class Daemon
      include Cognizant::Logging

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

      # Array of processes being managed.
      # @private
      # @return [Array]
      attr_accessor :processes

      # Initializes and starts the cognizant daemon with the given options
      # as instance attributes.
      # @param [Hash] options A hash of instance attributes and their values.
      def initialize(options = {})
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
        @pidfile  = File.expand_path(@pidfile)
        @logfile  = File.expand_path(@logfile)
        @socket   = File.expand_path(@socket)
        @pids_dir = File.expand_path(@pids_dir)
        @logs_dir = File.expand_path(@logs_dir)

        # Only accepted through a config stdin/file.
        @processes_to_monitor = options[:monitor] || nil
      end

      def bootup
        setup_prerequisites
        trap_signals
        log.info "Booting up cognizantd..."
        EventMachine.run do
          preload_processes
          start_interface_server
          start_periodic_ticks
          daemonize
        end
      end

      # Stops the TCP server and the tick loop, and performs cleanup.
      def shutdown
        log.info "Shutting down cognizantd..."
        # logger.close

        EventMachine.next_tick { EventMachine.stop }
      end

      private

      def preload_processes
        self.processes = {}
        @processes_to_monitor.each do |name, attributes|
          process = Cognizant::Process.new(attributes.merge({ name: name }))
          self.processes[name] = process
          process.monitor
        end
      end

      # Starts the TCP server with the set socket lock file or port.
      def start_interface_server
        if port = @port
          log.info "Starting the TCP server at #{@port}..."
          host = "127.0.0.1"
          splitted = port.to_s.split(":")
          host, port = splitted if splitted.size > 1
          EventMachine.start_server(host, port, Server::Interface)
        else  
          log.info "Starting the UNIX domain server with socket #{@socket}..."
          EventMachine.start_unix_domain_server(@socket, Server::Interface)
        end
      end

      # Starts the loop that defines the time window for determining and acting upon process states.
      def start_periodic_ticks
        log.info "Starting the periodic tick..."
        EventMachine.add_periodic_timer(1) do
          puts "self.processes: [#{self.processes}]"
          self.processes.each do |group, process|
            process.tick
          end
        end
        # EventMachine.next_tick {
        #   @redis = Cognizant::Process.new({
        #     name: "redis-server",
        #     autostart: true,
        #     start_command: "/usr/local/bin/redis-server -",
        #     start_with_input: "daemonize no",
        #     start_timeout: 2,
        #     stop_timeout: 2,
        #     restart_timeout: 2
        #   })
        #   @redis.stop if @redis
        #   self.processes[@redis.name] = @redis
        #   @redis.monitor
        # }
      end

      def setup_prerequisites
        # Create the require directories.
        [File.dirname(@pidfile), File.dirname(@logfile), @pids_dir, @logs_dir, File.dirname(@socket)].each do |directory|
          FileUtils.mkdir_p(directory)
        end

        # Setup logging.
        add_log_adapter(File.open(@logfile, "a"))
        add_log_adapter($stdout) unless @daemonize
        log.level = if @trace then Logger::DEBUG else @loglevel end
      end

      def trap_signals
        terminator = Proc.new do
          log.info "Received signal to shutdown."
          shutdown
        end

        Signal.trap('TERM', &terminator)
        Signal.trap('INT',  &terminator)
        Signal.trap('QUIT', &terminator)
      end

      # Daemonize the current process and save it pid in a file.
      def daemonize
        if @daemonize
          log.info "Daemonizing into the background..."
          ::Process.daemon

          pid = ::Process.pid

          if @pidfile
            log.info "Writing the daemon pid (#{pid}) to the pidfile..."
            File.open(@pidfile, "w") { |f| f.write(pid) }
          end
        end
      end
    end
  end
end
