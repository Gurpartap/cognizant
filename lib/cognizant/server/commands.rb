require "json"
require "cognizant/system"

module Cognizant
  module Server
    module Commands
      def self.load(config_file)
        Cognizant::Server.daemon.load(config_file)
        # yield("OK")
      end

      def self.status(*args)
        output_processes = []
        if args.size > 0
          Cognizant::Server.daemon.processes.values.each do |process|
            output_processes << process if args.include?(process.name) or args.include?(process.group)
          end
          if output_processes.size == 0
            raise("ERROR: No such process")
            # yield("OK")
          end
        else
          output_processes = Cognizant::Server.daemon.processes.values
        end
        
        output = []
        output_processes.each do |process|
          pid = process.read_pid
          output << {
            "Process" => process.name,
            "PID"     => pid,
            "Group"   => process.group,
            "State"   => process.state,
            "Since"   => process.last_transition_time,
            "% CPU"   => System.cpu_usage(pid).to_f,
            "Memory"  => System.memory_usage(pid).to_f # in KBs.
          }
        end
        yield(output.to_json)
        # yield("OK")
      end

      %w(monitor start stop restart unmonitor).each do |action|
        class_eval <<-END
          def self.#{action}(*args)
            unless args.size > 0
              raise("ERROR: Missing process name")
              return # yield("OK")
            end
            output_processes = []
            Cognizant::Server.daemon.processes.values.each do |process|
              if args.include?(process.name) or args.include?(process.group)
                output_processes << process
              end
            end

            if output_processes.size == 0
              raise("ERROR: No such process")
              # yield("OK")
            else
              output_processes.each do |process|
                process.#{action} # TODO: process.handle_user_command(#{action})
              end
            end
          end
        END
      end

      def self.shutdown
        Cognizant::Server.daemon.shutdown
        # yield("OK")
      end

      def self.method_missing(command, *args)
        raise("ERROR: Unknown command '#{command}'")
        # yield("OK")
      end
    end
  end
end
