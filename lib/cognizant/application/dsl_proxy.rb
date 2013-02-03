module Cognizant
  class Application
    class DSLProxy
      attr_accessor :attributes

      def initialize(application, &dsl_block)
        @application = application
        @attributes = Hash.new
        instance_eval(&dsl_block)
      end

      def method_missing(name, *args, &block)
        if args.size == 1 and name.to_s =~ /^(.*)=$/
          @attributes[$1.to_sym] = args.first
        elsif args.size == 1
          @attributes[name.to_sym] = args.first
        elsif args.size == 0 and name.to_s =~ /^(.*)!$/
          @attributes[$1.to_sym] = true
        elsif args.empty? and @attributes.key?(name.to_sym)
          @attributes[name.to_sym]
        else
          super
        end
      end

      def monitor(process_name = nil, attributes = {}, &block)
        @application.monitor(process_name, attributes, &block)
      end

      def process(process_name = nil, attributes = {}, &block)
        @application.process(process_name, attributes, &block)
      end
    end
  end
end
