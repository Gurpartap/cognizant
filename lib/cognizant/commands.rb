require "json"
require "cognizant/client"
require "cognizant/system"

module Cognizant
  module Commands
    @@commands = {}

    def self.command(name, description = nil, &block)
      @@commands[name] = { :description => description, :block => block }
    end

    def self.process_command(connection, command)
      response = generate_response(connection, command)
      if !response.nil?
        send_message(connection, response)
      else
        Cognizant.log.debug("Got back nil response, so not responding to command.")
      end
      # connection.close_connection_after_writing
    end

    def self.send_message(connection, response)
      if response.kind_of?(String)
        response = { 'message' => response }
      end
      serialized_message = Cognizant::Client::Transport.serialize_message(response)
      connection.send_data(serialized_message)
    end

    def self.generate_response(connection, command)
      begin
        request = Cognizant::Client::Transport.deserialize_message(command)
      rescue ArgumentError => e
        return { 'message' => "Could not parse command: #{e}" }
      end

      unless command_name = request['command']
        return { 'message' => 'No "command" parameter provided; not sure what you want me to do.' }
      end

      run_command(connection, request, command, command_name)
    end

    def self.run_command(connection, request, command, command_name)
      if command_spec = @@commands[command_name]
        Cognizant.log.debug("Received command: #{command.inspect}")
        begin
          return command_spec[:block].call(connection, request)
        rescue StandardError => e
          msg = "Error while processing command #{command_name.inspect}: #{e} (#{e.class})\n  #{e.backtrace.join("\n  ")}"
          Cognizant.log.error(msg)
          return msg
        end
      else
        Cognizant.log.debug("Received unrecognized command: #{command.inspect}")
        return unrecognized_command(connection, request)
      end
    end

    def self.command_descriptions
      command_specs = @@commands.select do |_, spec|
        spec[:description]
      end.sort_by {|name, _| name}

      command_specs.map do |name, spec|
        "#{name}: #{spec[:description]}"
      end.join("\n")
    end

    def self.unrecognized_command(connection, request)
      <<EOF
Unrecognized command: #{request['command'].inspect}

#{command_descriptions}
EOF
    end

    # Used by cognizant shell.
    command '_ehlo' do |conn, request|
      <<EOF
Welcome #{request['user']}! You are speaking to the Cognizant Monitoring Daemon.
EOF
    end

    # Used by cognizant shell.
    command '_autocomplete_keywords' do |conn, request|
      @@commands.keys.reject { |c| c =~ /^\_.+/ } + Cognizant::Daemon.processes.keys
    end

    command 'help', 'Print out available commands' do
"You are speaking to the Cognizant command socket. You can run the following commands:

#{command_descriptions}
"
    end

    command("load", "Loads the process information from specified Ruby file") do |connection, request|
      request["args"].each do |file|
        Cognizant::Daemon.load(file)
      end
      # send_process_or_group_status
      "OK"
    end

    command('help', 'Print out available commands') do
"You are speaking to the Cognizant command socket. You can run the following commands:

#{command_descriptions}
"
    end

    # command('reload', 'Reload Cognizant') do |connection, _|
    #   # TODO: make reload actually work (command socket reopening is
    #   # an issue). Would also be nice if user got a confirmation that
    #   # the reload completed, though that's not strictly necessary.
    # 
    #   # In the normal case, this will do a write
    #   # synchronously. Otherwise, the bytes will be stuck into the
    #   # buffer and lost upon reload.
    #   send_message(connection, 'Reloading, as commanded')
    #   Cognizant.reload
    # 
    #   # Reload should not return
    #   raise "Not reachable"
    # end

    command("status", "Display status of managed process(es) or group(s)") do |connection, request|
      send_process_or_group_status(request["args"])
    end

    [
      ["monitor",   "Monitor the specified process or group"],
      ["unmonitor", "Unmonitor the specified process or group"],
      ["start",     "Start the specified process or group"],
      ["stop",      "Stop the specified process or group"],
      ["restart",   "Restart the specified process or group"]
    ].each do |(name, description)|
      command(name, description) do |connection, request|
        args = request["args"]
        unless args.size > 0
          raise("Missing process name")
          return
        end
        output_processes = []
        output_processes = processes_for_name_or_group(args)
        if output_processes.size == 0
          raise("No such process")
        else
          output_processes.each do |process|
            process.handle_user_command(name)
          end
        end
        # send_process_or_group_status(args)
        "OK"
      end
    end

    command("shutdown", "Stop the monitoring daemon without affecting managed processes") do |connection, _|
      Cognizant::Daemon.shutdown
    end

    def self.processes_for_name_or_group(args)
      processes = []
      Cognizant::Daemon.processes.values.each do |process|
        processes << process if args.include?(process.name) or args.include?(process.group)
      end
      processes
    end

    def self.send_process_or_group_status(args = [])
      output_processes = []
      if args.size > 0
        output_processes = processes_for_name_or_group(args)
        raise "No such process" if output_processes.size == 0
      else
        output_processes = Cognizant::Daemon.processes.values
      end

      format_process_or_group_status(output_processes)
    end

    def self.format_process_or_group_status(output_processes)
      output = []
      output_processes.each do |process|
        pid = process.cached_pid
        output << {
          "Process" => process.name,
          "PID"     => pid,
          "Group"   => process.group,
          "State"   => process.state,
          "Since"   => process.last_transition_time,
          "% CPU"   => Cognizant::System.cpu_usage(pid).to_f,
          "Memory"  => Cognizant::System.memory_usage(pid).to_f # in KBs.
        }
      end
      output
    end
  end
end
