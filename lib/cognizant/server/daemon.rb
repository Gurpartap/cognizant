require "logger"
require "eventmachine"

require "cognizant/validations"
require "cognizant/server/interface"

module Cognizant
  module Server
    class Daemon
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
      attr_accessor :uid

      # Run the daemon and managed processes as the given user group.
      # e.g. "deploy"
      # @return [String] Defaults to nil
      attr_accessor :gid

      # Directory to store pid files of managed processes into, when required.
      # e.g. /Users/Gurpartap/.cognizant/pids/
      # @return [String] Defaults to /var/run/cognizant/pids/
      attr_accessor :process_pids_dir

      # Directory to store the log files of managed processes, when required.
      # e.g. /Users/Gurpartap/.cognizant/logs/
      # @return [String] Defaults to /var/log/cognizant/logs/
      attr_accessor :process_logs_dir

      # The socket lock file for the server. This file is ignored if valid
      # bind address and port are given.
      # e.g. /Users/Gurpartap/.cognizant/cognizant-server.sock
      # @return [String] Defaults to /var/run/cognizant/cognizant-server.sock
      attr_accessor :server_socket

      # The interface to bind the TCP server to. e.g. "127.0.0.1".
      # @return [String] Defaults to nil
      attr_accessor :server_bind_address

      # The TCP port to start the server with. e.g. 8081.
      # @return [Integer] Defaults to nil
      attr_accessor :server_port

      # Secure the access to the server with this username and accompanying
      # password. e.g. "cognizant-user"
      # @return [String] Defaults to nil
      attr_accessor :server_username

      # Password to accompany the username for authentication validation.
      # e.g. "areallyverylongpasswordbecauseitmatters"
      # @return [String] Defaults to nil
      attr_accessor :server_password

      # Initializes and starts the cognizant daemon with the given options
      # as instance attributes.
      # @param [Hash] options A hash of instance attributes and their values.
      def initialize(options = {})
        validate({
          :pidfile          => "~/.cognizant/cognizantd.pid",
          :logfile          => "~/.cognizant/cognizant.log",
          :process_pids_dir => "~/.cognizant/pids/",
          :process_logs_dir => "~/.cognizant/logs/",
          :server_socket    => "~/.cognizant/cognizant-server.sock"
        })
        EventMachine.run do
          start_interface_server
          start_periodic_ticks
        end
      end

      private

      # Override defaults and validate the given options.
      def validate(options = {})
        @foreground          = options[:foreground]          || false
        @pidfile             = options[:pidfile]             || "/var/run/cognizant/cognizantd.pid"
        @logfile             = options[:logfile]             || "/var/log/cognizant/cognizantd.log"
        @loglevel            = options[:loglevel]            || Logger::INFO
        @process_pids_dir    = options[:process_pids_dir]    || "/var/run/cognizant/pids/"
        @process_logs_dir    = options[:process_logs_dir]    || "/var/log/cognizant/logs/"
        @server_socket       = options[:server_socket]       || "/var/run/cognizant/cognizant-server.sock"
        @server_bind_address = options[:server_bind_address] || nil
        @server_port         = options[:server_port]         || nil
        @server_username     = options[:server_username]     || nil
        @server_password     = options[:server_password]     || nil
        @env                 = options[:env]                 || {}
        @chdir               = options[:chdir]               || nil
        @umask               = options[:umask]               || 0022
        @uid                 = options[:uid]                 || nil
        @gid                 = options[:gid]                 || nil

        Validations.validate_file_writable(@pidfile)
        Validations.validate_file_writable(@logfile)
        Validations.validate_includes(@loglevel, [Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR, Logger::FATAL])
        Validations.validate_directory_writable(@process_pids_dir)
        Validations.validate_directory_writable(@process_logs_dir)
        Validations.validate_file_writable(@server_socket)

        if @server_bind_address and not @server_port
          raise Validations::ValidationError, "Missing server port."
        end

        if @server_username and not @server_password
          raise Validations::ValidationError, "Missing password."
        end

        if @chdir and not File.directory?(@chdir)
          raise Validations::ValidationError, %{The directory "#{@chdir}" is not available.}
        end

        Validations.validate_env(@env)
        Validations.validate_umask(@umask)
        Validations.validate_user(@uid)
        Validations.validate_user_group(@gid)
      end

      # Starts the TCP server with the set socket lock file or port.
      def start_interface_server
        # if @server_bind_address and @server_port
        #   EventMachine.start_server(server_bind_address || "127.0.0.1", server_port, Cognizant::Server::Interface)
        # else
        #   EventMachine.start_unix_domain_server(server_socket, Cognizant::Server::Interface)
        # end
      end

      # Starts the loop that defines the time window for determining and acting upon process states.
      def start_periodic_ticks
        EventMachine.add_periodic_timer(1) do
          print "."
        end
      end

      # Stops the TCP server and the tick loop.
      def shutdown
        EventMachine.stop
      end
    end
  end
end
