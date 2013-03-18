module Cognizant
  module Commands
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
        output_processes = processes_for_name_or_group(request["app"], args)
        if output_processes.size == 0
          raise("No such process")
        else
          output_processes.each do |process|
            process.handle_user_command(name)
          end
        end
        # send_process_or_group_status(request["app"], args)
        "OK"
      end
    end
  end
end
