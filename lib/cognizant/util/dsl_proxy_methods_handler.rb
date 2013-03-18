module Cognizant
  module Util
    module DSLProxyMethodsHandler
      attr_accessor :attributes

      def initialize(entity, &dsl_block)
        @attributes = Hash.new
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
    end
  end
end
