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
      # @return [String] Defaults to /var/run/cognizantd.pid
      attr_accessor :pidfile

      # The file to log the daemon's operations information into.
      # e.g. /Users/Gurpartap/.cognizant/cognizantd.log
      # @return [String] Defaults to /var/log/cognizantd.log
      attr_accessor :logfile

      # The level of information to log. Possible values include Logger::DEBUG,
      # Logger::INFO, Logger::WARN, Logger::ERROR and Logger::FATAL.
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
      # @return [String] Defaults to 022
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

      # Initializes and starts the cognizant daemon with the given options.
      # @param [Hash] options A hash of instance attributes and their values.
      def initialize(options = {})
        validate(options)
        EventMachine.run do
          start_interface_server
          start_periodic_ticks
        end
      end

      private

      # Override defaults and validate the given options.
      # @param [Hash] options A hash of instance attributes and their values.
      def validate(options = {})
        @foreground          = options[:foreground]          || false
        @pidfile             = options[:pidfile]             || "/var/run/cognizantd.pid"
        @logfile             = options[:logfile]             || "/var/log/cognizant.log"
        @loglevel            = options[:loglevel]            || Logger::INFO
        @env                 = options[:env]                 || {}
        @chdir               = options[:chdir]               || nil
        @umask               = options[:umask]               || 022
        @uid                 = options[:uid]                 || nil
        @gid                 = options[:gid]                 || nil
        @process_pids_dir    = options[:process_pids_dir]    || "/var/run/cognizant/pids/"
        @process_logs_dir    = options[:process_logs_dir]    || "/var/log/cognizant/logs/"
        @server_socket       = options[:server_socket]       || "/var/run/cognizant/cognizant-server.sock"
        @server_bind_address = options[:server_bind_address] || nil
        @server_port         = options[:server_port]         || nil
        @server_username     = options[:server_username]     || nil
        @server_password     = options[:server_password]     || nil

        Validations.validate_file_writable(@pidfile)
        Validations.validate_file_writable(@logfile)
        Validations.validate_directory_writable(@process_pids_dir)
        Validations.validate_directory_writable(@process_logs_dir)
      end

      def start_interface_server
        EventMachine.start_unix_domain_server(server_socket)
        EventMachine.start_server(server_address, server_port, Cognizant::Server::Interface)
      end

      def start_periodic_ticks
        EventMachine.add_periodic_timer(1) do
          print "."
        end
      end
    end
  end
end
