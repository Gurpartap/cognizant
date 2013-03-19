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
        Log[self].debug("Got back nil response, so not responding to command.")
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
        # Log[self].debug("Received command: #{command.inspect}")
        begin
          return command_spec[:block].call(connection, request)
        rescue StandardError => e
          msg = "Error while processing command #{command_name.inspect}: #{e} (#{e.class})\n  #{e.backtrace.join("\n  ")}"
          Log[self].error(msg)
          return msg
        end
      else
        Log[self].debug("Received unrecognized command: #{command.inspect}")
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
      if request["app"].to_s.size > 0 and Cognizant::Controller.daemon.applications.has_key?(request["app"].to_sym)
        use = request["app"]
      else
        use = Cognizant::Controller.daemon.applications.keys.first
      end

      message = <<EOF
Welcome #{request['user']}! You are speaking to the Cognizant Monitoring Daemon.
EOF

      { "message" => message, "use" => use }
    end

    # Used by cognizant shell.
    command '_autocomplete_keywords' do |conn, request|
      keywords = []
      keywords += @@commands.keys.reject { |c| c =~ /^\_.+/ }
      keywords += Cognizant::Controller.daemon.applications.keys
      keywords += Cognizant::Controller.daemon.applications[request["app"].to_sym].processes.keys if request.has_key?("app") and request["app"].to_s.size > 0
      keywords
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

    def self.processes_for_name_or_group(app, args)
      processes = []
      if app.to_s.size > 0
        Cognizant::Controller.daemon.applications[app.to_sym].processes.values.each do |process|
          processes << process if args.include?(process.name) or args.include?(process.group)
        end
      end
      processes
    end

    def self.send_process_or_group_status(app, args = [])
      output_processes = []
      if args.size > 0
        output_processes = processes_for_name_or_group(app, args)
        return %Q{No such process or group: #{args.join(', ')}} if output_processes.size == 0
      else
        output_processes = Cognizant::Controller.daemon.applications[app.to_sym].processes.values
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

require "cognizant/commands/actions"
require "cognizant/commands/help"
require "cognizant/commands/load"
require "cognizant/commands/shutdown"
require "cognizant/commands/status"
require "cognizant/commands/use"
