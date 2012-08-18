module Cognizant
  module Server
    module Commands
      def self.load(config_file)
        Cognizant::Server.daemon.load(config_file)
        yield("OK")
      end

      def self.status(*args)
        if process_name = args.shift
          Cognizant::Server.daemon.processes.each do |name, process|
            if process.name.eql?(process_name)
              yield("#{process.name}: #{process.state}")
              return yield("OK")
            end
          end  
          yield("ERR: No such process")
          return yield("OK")
        end
        yield("OK")
      end

      %w(monitor start stop restart unmonitor).each do |action|
        class_eval <<-END
          def self.#{action}(*args)
            unless process_name = args.shift
              yield("ERR: Missing process name")
              return yield("OK")
            end
            Cognizant::Server.daemon.processes.each do |name, process|
              if process.name.eql?(process_name)
                process.#{action}
                return yield("OK")
              end
            end
            yield("ERR: No such process")
            yield("OK")
          end
        END
      end

      def self.shutdown
        Cognizant::Server.daemon.shutdown
        yield("OK")
      end

      def self.method_missing(command, *args)
        yield("ERR: Unknown command '#{command}'")
        yield("OK")
      end
    end
  end
end
