module Cognizant
  module Server
    module System
      class PidFile
        def initialize(file, pid = nil)
          @file = file
          @pid = pid if pid
        end

        def read
          File.open(@file, "r") { |f| @pid = f.read }
        end

        def write
          File.open(@file, "w") { |f| f.write(@pid) }
        end
      end
    end
  end
end