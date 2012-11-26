module Cognizant
  class Process
    module PID
      def cached_pid
        @process_pid and @process_pid != 0 ? @process_pid : read_pid
      end

      def read_pid
        if self.pid_command
          str = execute(self.pid_command).stdout.to_i
          process_pid = str unless not str or str.zero?
          # TODO: Write pid to pidfile, since our source was pid_command instead.
        elsif self.pidfile and File.exists?(self.pidfile)
          str = File.read(self.pidfile).to_i
          process_pid = str unless not str or str.zero?
        end
        process_pid = 0 unless System.pid_running?(process_pid) # If the newly fetched pid is not running, reset it.
        @process_pid = process_pid
      end

      def write_pid(pid = nil)
        @process_pid = pid if pid
        File.open(self.pidfile, "w") { |f| f.write(@process_pid) } if self.pidfile and @process_pid
      end

      def unlink_pid
        File.unlink(self.pidfile) if self.pidfile
      rescue Errno::ENOENT
        # It got deleted before we could. Perhaps it was a process managed pidfile.
        true
      end
    end
  end
end
