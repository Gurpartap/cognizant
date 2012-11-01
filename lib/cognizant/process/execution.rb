module Cognizant
  class Process
    module Execution
      ExecutionResult = Struct.new(
        :pid,
        :stdout,
        :stderr,
        :exit_code,
        :succeeded
      ) do alias succeeded? succeeded end

      def execute(command, options = {})
        options[:groups] ||= []
        options[:env]    ||= {}

        pid, pid_w = IO.pipe

        unless options[:daemonize]
          # Stdout and stderr file descriptors.
          out_r, out_w = IO.pipe
          err_r, err_w = IO.pipe
        end

        # Run the following in a fork so that the privilege changes do not affect the parent process.
        fork_pid = ::Process.fork do
          # Set the user and groups for the process in context.
          drop_privileges(options)

          if options[:daemonize]
            # Create a new session to detach from the controlling terminal.
            unless ::Process.setsid
              # raise Koth::RuntimeException.new('cannot detach from controlling terminal')
            end

            # TODO: Set pgroup: true so that the spawned process is the group leader, and it's death would kill all children as well.

            # Prevent inheriting signals from parent process.
            Signal.trap('TERM', 'SIG_DFL')
            Signal.trap('INT',  'SIG_DFL')
            Signal.trap('HUP',  'SIG_DFL')

            # Give the process a name.
            $0 = options[:name] if options[:name]

            # Collect logs only when daemonizing.
            stdout = [options[:logfile] || "/dev/null", "a"]
            stderr = [options[:errfile] || options[:logfile] || "/dev/null", "a"]
          else
            stdout = out_w
            stderr = err_w
          end

          # TODO: Run popen as spawned process before privileges are dropped for increased abilities?
          stdin_data = options[:input] if options[:input]
          stdin_data = IO.popen(options[:input_command]).gets if options[:input_command]

          if stdin_data
            stdin, stdin_w = IO.pipe
            stdin_w.write stdin_data
            stdin_w.close # stdin is closed by ::Process.spawn.
          elsif options[:input_file] and File.exists?(options[:input_file])
            stdin = options[:input_file]
          else
            stdin = "/dev/null"
          end

          # Merge spawn options.
        	spawn_options = construct_spawn_options(options, {
        		:in  => stdin,
        		:out => stdout,
        		:err => stderr
        	})

          # Spawn a process to execute the command.
          process_pid = ::Process.spawn(options[:env], command, spawn_options)
          # puts "process_pid: #{process_pid} (#{command})"
          pid_w.write(process_pid)

          if options[:daemonize]
            # We do not care about actual status or output when daemonizing.
            exit(0)
          else
            # TODO: Timeout here, in case the process doesn't daemonize itself.

            # Wait (blocking) until the command has finished running.
            status = ::Process.waitpid2(process_pid)[1]

            # Pass on the exit status to the parent.
            exit(status.exitstatus || 0) # TODO: This 0 or something else should be controlled by timeout handler.
          end
        end

        # Close the pid file descriptor.
        pid_w.close

        if options[:daemonize]
          # Detach (non blocking) the process executing the command and move on.
          ::Process.detach(fork_pid)

          return ExecutionResult.new(
            pid.read.to_i,
            nil,
            nil,
            0,
            true
          )
        else
          # Wait until the fork has finished running and accept the exit status.
          status = ::Process.waitpid2(fork_pid)[1]

          # Timeout and try (detach + pid_running?)?

          # Close the file descriptors.
          out_w.close
          err_w.close

          # Collect and return stdout, stderr and exitcode.
          return ExecutionResult.new(
            pid.read.to_i,
            out_r.read,
            err_r.read,
            status.exitstatus,
            status.exitstatus.zero?
          )
        end
      end

      private

      def drop_privileges(options = {})
        # Cannot drop privileges unless we are superuser.
        if ::Process.euid == 0
          # Drop ~= decrease, since we can only decrease privileges.

          # For clarity.
          uid    = options[:uid]
          gid    = options[:gid]
          groups = options[:groups]

          # Find the user and primary group in the password and group database.
          user  = (uid.is_a? Integer) ? Etc.getpwuid(uid) : Etc.getpwnam(uid) if uid
          group = (gid.is_a? Integer) ? Etc.getgruid(gid) : Etc.getgrnam(gid) if gid

          # Collect the secondary groups' GIDs.
          group_ids = groups.map { |g| Etc.getgrnam(g).gid } if groups

          # Set the fork's secondary user groups for the spawn process to inherit.
          ::Process.groups = [group.gid] if group # Including the primary group.
          ::Process.groups |= group_ids if groups and !group_ids.empty?

          # Set the fork's user and primary group for the spawn process to inherit.
          ::Process.uid = user.uid  if user
          ::Process.gid = group.gid if group

          # Find and set the user's HOME environment variable for fun.
          options[:env] = options[:env].merge({ 'HOME' => user.dir }) if user and user.dir

          # Changes the process' idea of the file system root.
          Dir.chroot(options[:chroot]) if options[:chroot]

          # umask and chdir drops are managed by ::Process.spawn.
        end
      end

      private

      def construct_spawn_options(options, overrides = {})
        spawn_options = {}
        [:chdir, :umask].each do |o|
          spawn_options[o] = options[o] if options[o]
        end
        spawn_options.merge(overrides)
      end
    end
  end
end
