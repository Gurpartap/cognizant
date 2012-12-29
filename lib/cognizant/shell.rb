require "logger"
require "optparse"

require "readline"
require "shellwords"

require "cognizant/client"

module Cognizant
  class Shell
    def initialize(options = {})
      @path_to_socket = "/var/run/cognizant/cognizantd.sock"
      @path_to_socket = options[:socket] if options.has_key?(:socket) and options[:socket].to_s.size > 0

      @@is_shell = true
      @@is_shell = options[:shell] if options.has_key?(:shell)

      @autocomplete_keywords = []
      connect
    end

    def run(&block)
      Signal.trap("INT") do
        Cognizant::Shell.emit("\nGoodbye!")
        exit(0)
      end

      emit("Enter 'help' if you're not sure what to do.")
      emit
      emit('Type "quit" or "exit" to quit at any time')

      setup_readline(&block)
    end

    def setup_readline(&block)
      Readline.completion_proc = Proc.new do |input|
        case input
        when /^\//
          # Handle file and directory name autocompletion.
          Readline.completion_append_character = "/"
          Dir[input + '*'].grep(/^#{Regexp.escape(input)}/)
        else
          # Handle commands and process name autocompletion.
          Readline.completion_append_character = " "
          @autocomplete_keywords.grep(/^#{Regexp.escape(input)}/)
        end
      end

      while (line = Readline.readline('> ', true).strip.to_s).size > 0
        command, args = parse_command(line)
        return emit("Goodbye!") if ['quit', 'exit'].include?(command)
        run_command(command, args, &block)
      end
    end

    def run_command(command, args, &block)
      command = command.to_s
      begin
        response = @client.command({'command' => command, 'args' => args})
      rescue Errno::EPIPE => e
        emit("cognizant: Error communicating with cognizantd: #{e} (#{e.class})")
        exit(1)
      end

      if block
        block.call(response, command)
      elsif response.kind_of?(Hash)
        puts response['message']
      else
        puts "Invalid response type #{response.class}: #{response.inspect}"
      end
    end

    def parse_command(line)
      command, *args = Shellwords.shellsplit(line)
      [command, args]
    end

    def connect
      begin
        @client = Cognizant::Client.for_path(@path_to_socket)
      rescue Errno::ENOENT => e
        # TODO: The exit here is a biit of a layering violation.
        Cognizant::Shell.emit(<<EOF, true)
Could not connect to Cognizant daemon process:

  #{e}

HINT: Are you sure you are running the Cognizant daemon?  If so, you
should pass cognizant the socket argument provided to cognizantd.
EOF
        exit(1)
      end
      ehlo if interactive?
      fetch_autocomplete_keywords
    end

    def ehlo
      response = @client.command('command' => '_ehlo', 'user' => ENV['USER'])
      emit(response['message'])
    end

    def fetch_autocomplete_keywords
      @autocomplete_keywords = @client.command('command' => '_autocomplete_keywords')
    end

    def self.emit(message = nil, force = false)
      $stdout.puts(message || '') if interactive? || force
    end

    def self.interactive?
      # TODO: It is not a tty during tests.
      # $stdin.isatty and @@is_shell
      @@is_shell
    end

    def emit(*args)
      self.class.emit(*args)
    end

    def interactive?
      self.class.interactive?
    end
  end
end
