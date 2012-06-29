require "eventmachine"

require "cognizant/logging"
require "cognizant/system"
require "cognizant/validations"
require "cognizant/server/interface"

module Cognizant
  module Server
    class Daemon
      include Cognizant::Logging

      # Run the daemon in the foreground.
      # @return [true, false] Defaults to false
      attr_accessor :foreground

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

      # Environment variables for managed processes to inherit.
      # @return [Hash] Defaults to {}
      attr_accessor :env

      # The current working directory for the managed processes to start with.
      # @return [String] Defaults to nil
      attr_accessor :chdir

      # Limit the permission modes for files and directories created by the
      # daemon and the managed processes.
      # @return [Integer] Defaults to 0022
      attr_accessor :umask

      # Run the daemon and managed processes as the given user.
      # e.g. "deploy", 1000
      # @return [String] Defaults to nil
      attr_accessor :user

      # Run the daemon and managed processes as the given user group.
      # e.g. "deploy"
      # @return [String] Defaults to nil
      attr_accessor :group

      # Directory to store the pid files of managed processes, when required.
      # e.g. /Users/Gurpartap/.cognizant/pids/
      # @return [String] Defaults to /var/run/cognizant/pids/
      attr_accessor :pids_dir

      # Directory to store the log files of managed processes, when required.
      # e.g. /Users/Gurpartap/.cognizant/logs/
      # @return [String] Defaults to /var/log/cognizant/logs/
      attr_accessor :logs_dir

      # The socket lock file for the server. This file is ignored if valid
      # bind address and port are given.
      # e.g. /Users/Gurpartap/.cognizant/cognizant-server.sock
      # @return [String] Defaults to /var/run/cognizant/cognizant-server.sock
      attr_accessor :socket

      # The interface to bind the TCP server to. e.g. "127.0.0.1".
      # @return [String] Defaults to nil
      attr_accessor :bind_address

      # The TCP port to start the server with. e.g. 8081.
      # @return [Integer] Defaults to nil
      attr_accessor :port

      # Username for securing server access. e.g. "cognizant-user"
      # @return [String] Defaults to nil
      attr_accessor :username

      # Password to accompany the username.
      # e.g. "areallyverylongpasswordbecauseitmatters"
      # @return [String] Defaults to nil
      attr_accessor :password

      # Initializes and starts the cognizant daemon with the given options
      # as instance attributes.
      # @param [Hash] options A hash of instance attributes and their values.
      def initialize(options = {})
        @foreground          = options[:foreground]    || false
        @pidfile             = options[:pidfile]       || "/var/run/cognizant/cognizantd.pid"
        @logfile             = options[:logfile]       || "/var/log/cognizant/cognizantd.log"
        @loglevel            = options[:loglevel].to_i || Logger::INFO
        @pids_dir            = options[:pids_dir]      || "/var/run/cognizant/pids/"
        @logs_dir            = options[:logs_dir]      || "/var/log/cognizant/logs/"
        @socket              = options[:socket]        || "/var/run/cognizant/cognizant-server.sock"
        @bind_address        = options[:bind_address]  || nil
        @port                = options[:port]          || nil
        @username            = options[:username]      || nil
        @password            = options[:password]      || nil
        @env                 = options[:env]           || {}
        @chdir               = options[:chdir]         || nil
        @umask               = options[:umask]         || 0022
        @user                = options[:user]          || nil
        @group               = options[:group]         || nil

        return validate if options[:validate]

        add_log_adapter(File.open(@logfile, "a"))
        add_log_adapter($stdout) if @foreground

        log.level = if options[:trace] then Logger::DEBUG else @loglevel end

        log.info "Booting up the cognizant daemon."

        EventMachine.run do
          start_interface_server
          start_periodic_ticks
          unless @foreground
            log.info "Daemonizing into the background."
            Process.daemon
          end
        end
      ensure
        logger.close
      end

      private

      # Starts the TCP server with the set socket lock file or port.
      def start_interface_server
        if @bind_address and @port
          log.info "Starting the TCP server at #{@bind_address}:#{@port}."
          EventMachine.start_server("127.0.0.1", 8081, Cognizant::Server::Interface)
        else  
          log.info "Starting the UNIX domain server with #{@socket}."
          EventMachine.start_unix_domain_server(@socket, Cognizant::Server::Interface)
        end
      end

      # Starts the loop that defines the time window for determining and acting upon process states.
      def start_periodic_ticks
        log.info "Starting the periodic tick."
        EventMachine.add_periodic_timer(1) do
          print "."
        end
      end

      # Stops the TCP server and the tick loop.
      def shutdown
        log.info "Shutting down cognizant."
        EventMachine.next_tick { EventMachine.stop }
      end

      # Override defaults and validate the given options.
      def validate
        if @bind_address and not @port
          raise Validations::ValidationError, "Missing server port."
        end

        if @username and not @password
          raise Validations::ValidationError, "Missing password."
        end
        
        if @chdir and not File.directory?(@chdir)
          raise Validations::ValidationError, %{The directory "#{@chdir}" is not available.}
        end
        
        Validations.validate_includes(@loglevel, [Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR, Logger::FATAL])
        Validations.validate_umask(@umask)
        
        fork_pid = Process.fork do
          begin
            Validations.validate_user(@user)
            Validations.validate_user_group(@group)
            Validations.validate_env(@env)

            System.drop_privileges(uid: @user, gid: @group, env: @env)

            Validations.validate_file_writable(@pidfile)
            Validations.validate_file_writable(@logfile)
            Validations.validate_directory_writable(@pids_dir)
            Validations.validate_directory_writable(@logs_dir)
            Validations.validate_file_writable(@socket, "socket")
          rescue => exception  
            if @foreground
              $stderr.puts "ERROR: While executing #{$0} ... (#{exception.class})"
              $stderr.puts "    #{exception.message}\n\n"
              if options[:trace]
                $stderr.puts exception.backtrace.join("\n")
                $stderr.puts "\n(See usage by running #{$0} with --help)"
              else
                $stderr.puts "(See full trace by running #{$0} with --trace)"
              end
              exit(1)
            else
              raise
            end
          end
        
          # Exit the forked process normally.
          exit(0)
        end
        status = Process.waitpid2(fork_pid)[1]
        
        # Validations failed if the fork did not exit normally.
        exit(status.exitstatus) unless status.success?
      end
    end
  end
end
