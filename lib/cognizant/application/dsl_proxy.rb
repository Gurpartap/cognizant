require 'cognizant/util/dsl_proxy_methods_handler'

module Cognizant
  class Application
    class DSLProxy
      include Cognizant::Util::DSLProxyMethodsHandler

      def initialize(application, &dsl_block)
        super
        @application = application
        instance_eval(&dsl_block)
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
