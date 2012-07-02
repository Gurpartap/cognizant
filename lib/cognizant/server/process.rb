module Cognizant
  module Server
    class Process
      # Unique name for the process.
      # @return [String]
      attr_accessor :name

      # Group for the process.
      # @return [String] Defaults to nil
      attr_accessor :group

      # Whether or not to auto start the process.
      # @return [true, false] Defaults to true
      attr_accessor :autostart

      # Whether or not to daemonize the process. It is recommended that
      # cognizant managed your process completely by process not
      # daemonizing itself. Find a non-daemonizing option in your process'
      # documentation.
      # @return [true, false] Defaults to true
      attr_accessor :daemonize

      # The pid lock file for the process. Required when daemonize is set to
      # false.
      # @return [String] Defaults to #{pids_dir}/#{name}.pid
      attr_accessor :pidfile

      # The file to log the process' STDOUT stream into.
      # @return [String] Defaults to #{logs_dir}/#{name}.log
      attr_accessor :logfile

      # The file to log the daemon's STDERR stream into.
      # @return [String] Defaults to #{logfile}
      attr_accessor :errfile

      # Environment variables for process.
      # @return [Hash] Defaults to {}
      attr_accessor :env

      # The chroot directory to change the process' idea of the file system
      # root.
      # @return [String] Defaults to nil
      attr_accessor :chroot

      # The current working directory for the process to start with.
      # @return [String] Defaults to nil
      attr_accessor :chdir

      # Limit the permission modes for files and directories created by the
      # process.
      # @return [Integer] Defaults to nil
      attr_accessor :umask

      # Run the process as the given user.
      # e.g. "deploy", 1000
      # @return [String] Defaults to nil
      attr_accessor :uid

      # Run the process as the given user group.
      # e.g. "deploy"
      # @return [String] Defaults to nil
      attr_accessor :gid

      # Supplementary user groups for the process.
      # e.g. ["staff"]
      # @return [Array] Defaults to []
      attr_accessor :groups

      # The command to start the process with.
      # e.g. "/usr/bin/redis-server"
      # @return [String] Defaults to nil
      attr_accessor :start_command

      # The grace time period in seconds for the process to start within.
      # After the timeout is over, the process the considered not started
      # and it re-enters the auto start lifecycle based on conditions.
      # @return [String] Defaults to 10
      attr_accessor :start_timeout

      # Start the process with this in it's STDIN.
      # e.g. "daemonize no"
      # @return [String] Defaults to nil
      attr_accessor :start_with_input

      # Start the process with this file's data in it's STDIN.
      # e.g. "/etc/redis/redis.conf"
      # @return [String] Defaults to nil
      attr_accessor :start_with_input_file

      # Start the process with this command's output in it's (process') STDIN.
      # e.g. "cat /etc/redis/redis.conf"
      # @return [String] Defaults to nil
      attr_accessor :start_with_input_command

      # The command to stop the process with.
      # e.g. "/usr/bin/redis-server"
      # @return [String] Defaults to nil
      attr_accessor :stop_command

      # The signals to pass to the process one by one attempting to stop it.
      # Each signal is passed within the timeout period over equally
      # distributed intervals. Override with signals without "KILL" to never
      # force kill a process.
      # e.g. ["TERM", "INT"]
      # @return [Array] Defaults to ["TERM", "INT", "KILL"]
      attr_accessor :stop_signals

      # The grace time period in seconds for the process to stop within.
      # After the timeout is over, the process is checked for alive status
      # and if not stopped, it re-enters the auto start lifecycle based on
      # conditions.
      # @return [String] Defaults to 10
      attr_accessor :stop_timeout

      # The command to restart the process with. This command should be similar
      # in behavior to the stop command, since the process will anyways be
      # automatically started again, if autostart is set to true.
      # @return [String] Defaults to nil
      attr_accessor :restart_command

      # The signals to pass to the process one by one attempting to restart it.
      # Each signal is passed within the timeout period over equally
      # distributed intervals. Override with signals without "KILL" to never
      # force kill a process.
      # e.g. ["TERM", "INT"]
      # @return [Array] Defaults to ["TERM", "INT", "KILL"]
      attr_accessor :restart_signals

      # The grace time period in seconds for the process to stop within
      # (for restart). After the timeout is over, the process is checked for
      # alive status and if not stopped, it re-enters the auto start lifecycle
      # based on conditions.
      # @return [String] Defaults to 10
      attr_accessor :restart_timeout
    end
  end
end
