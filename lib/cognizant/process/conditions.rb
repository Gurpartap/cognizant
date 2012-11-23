require "cognizant/process/conditions/condition"

Dir["#{File.dirname(__FILE__)}/conditions/*.rb"].each do |c|
  require c
end

module Cognizant
  class Process
    module Conditions
      def self.[](name)
        const_get(name.to_s.camelcase)
      end
    end
  end
end
