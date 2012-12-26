require "cognizant/process/triggers/trigger"

Dir["#{File.dirname(__FILE__)}/triggers/*.rb"].each do |trigger|
  require trigger
end

module Cognizant
  class Process
    module Triggers
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
