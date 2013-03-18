require "cognizant/process/conditions/poll_condition"

Dir["#{File.dirname(__FILE__)}/conditions/*.rb"].each do |condition|
  require condition
end

module Cognizant
  class Process
    module Conditions
      def self.[](name)
        begin
          const_get(name.to_s.camelcase)
        rescue NameError
          nil
        end
      end
    end
  end
end
