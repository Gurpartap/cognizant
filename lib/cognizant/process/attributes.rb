module Cognizant
  class Process
    module Attributes
      # Unique name for the process.
      # @return [String]
      attr_accessor :name

      # Group classification for the process.
      # @return [String] Defaults to nil
      attr_accessor :group

      # Whether or not to daemonize the process. It is recommended that
      # cognizant managed your process completely by process not
      # daemonizing itself. Find a non-daemonizing option in your process'
      # documentation.
      # @return [true, false] Defaults to true
      attr_accessor :daemonize

      # Whether or not to auto start the process on initial run. Afterwards,
      # this attribute is overwritten by stop or restart request.
      # @return [true, false] Defaults to true
      attr_accessor :autostart

      # The pid lock file for the process. Required when daemonize is set to
      # false.
      # @return [String] Defaults to value of pids_dir/name.pid
      attr_accessor :pidfile

      # The file to log the process' STDOUT stream into.
      # @return [String] Defaults to value of logs_dir/name.log
      attr_accessor :logfile

      # The file to log the daemon's STDERR stream into.
      # @return [String] Defaults to value of logfile
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

      # The command to check the running status of the process with. The exit
      # status of the command is used to determine the status.
      # e.g. "/usr/bin/redis-cli PING"
      # @return [String] Defaults to nil
      attr_accessor :ping_command

      # The command that returns the pid of the process.
      # @return [String] Defaults to nil
      attr_accessor :pid_command

      def daemonize!
        @daemonize = true
      end

      def autostart!
        @autostart = true
      end
    end
  end
end
