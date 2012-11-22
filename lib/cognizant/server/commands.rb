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
        if args.size == 1 and process_name = args.shift
          Cognizant::Server.daemon.processes.each do |process|
            if process.name.eql?(process_name)
              output_processes << process
            end
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
            "State"   => process.state
          }
        end
        yield(output.to_json)
        # yield("OK")
      end

      %w(monitor start stop restart unmonitor).each do |action|
        class_eval <<-END
          def self.#{action}(*args)
            unless process_name = args.shift
              raise("ERR: Missing process name")
              return # yield("OK")
            end
            Cognizant::Server.daemon.processes.each do |process|
              if process.name.eql?(process_name)
                process.#{action}
                return # yield("OK")
              end
            end
            raise("ERR: No such process")
            # yield("OK")
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
