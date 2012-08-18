require "logger"

module Cognizant
  module Logging
    extend self

    def add_log_adapter(file)
      @files ||= Array.new
      @files << file unless @files.include?(file)
      @logger = nil
    end

    def log
      @files ||= Array.new($stdout)
      @logger ||= Logger.new(Files.new(*@files))
    end
    alias :logger :log

    class Files
      def initialize(*files)
        @files = files
      end

      def write(*args)
        @files.each { |t| t.write(*args) }
      end

      def close
        @files.each(&:close)
      end
    end
  end
end
