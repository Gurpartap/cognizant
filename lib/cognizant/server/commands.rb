require "json"

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
          Cognizant::Server.daemon.processes.each do |process|
            output_processes << process if args.include?(process.name) or args.include?(process.group)
          end
          if output_processes.size == 0
            raise("ERR: No such process")
            # yield("OK")
          end
        else
          output_processes = Cognizant::Server.daemon.processes
        end
        
        output = []
        output_processes.each do |process|
          output << {
            "Process" => process.name,
            "Group"   => process.group,
            "State"   => process.state,
            "Since"   => process.last_transition_time
          }
        end
        yield(output.to_json)
        # yield("OK")
      end

      %w(monitor start stop restart unmonitor).each do |action|
        class_eval <<-END
          def self.#{action}(*args)
            unless args.size > 0
              raise("ERR: Missing process name")
              return # yield("OK")
            end
            output_processes = []
            Cognizant::Server.daemon.processes.each do |process|
              if args.include?(process.name) or args.include?(process.group)
                output_processes << process
              end
            end

            if output_processes.size == 0
              raise("ERR: No such process")
              # yield("OK")
            else
              output_processes.each do |process|
                process.#{action}
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
        raise("ERR: Unknown command '#{command}'")
        # yield("OK")
      end
    end
  end
end
