module Cognizant
  class Process
    class DSLProxy
      attr_accessor :attributes

      def initialize(process, &dsl_block)
        @process = process
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

      def check(condition_name, options, &block)
        @process.check(condition_name, options, &block)
      end

      def monitor_children(&child_process_block)
        @process.monitor_children(&child_process_block)
      end
    end
  end
end
