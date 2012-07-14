module Cognizant
  module Server
    module Commands
      def self.status(*args)
        if process = args.shift
          Cognizant::Server.daemon.processes.each do |name, p|
            if p.name.eql?(process)
              yield("redis-server: #{p.state}")
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
            unless process = args.shift
              yield("ERR: Missing process name")
              return yield("OK")
            end
            Cognizant::Server.daemon.processes.each do |name, p|
              if p.name.eql?(process)
                p.#{action}
                return yield("OK")
              end
            end
            yield("ERR: No such process")
            yield("OK")
          end
        END
      end

      def self.shutdown(*args)
        # yield("ERR: Extra arguments given")
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
