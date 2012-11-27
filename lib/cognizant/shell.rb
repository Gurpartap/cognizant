require "logger"
require "optparse"

require "readline"
require "shellwords"

require "cognizant/client"

module Cognizant
  class Shell
    def initialize(path_to_socket, is_shell = true)
      @path_to_socket = path_to_socket || "/var/run/cognizant/cognizantd.sock"
      @@is_shell = is_shell
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

      while line = Readline.readline('> ', true)
        if line.strip.to_s.size > 0
          command, args = parse_command(line)
          if ['quit', 'exit'].include?(command)
            emit("Goodbye!")
            return
          end
          run_command(command, args, &block)
        end
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
should pass cognizant the socket or tcp arguments provided to cognizantd.
EOF
        exit(1)
      end
      ehlo if interactive?
    end

    def ehlo
      response = @client.command('command' => 'ehlo', 'user' => ENV['USER'])
      emit(response['message'])
    end

    def self.emit(message = nil, force = false)
      $stdout.puts(message || '') if interactive? || force
    end

    def self.interactive?
      $stdin.isatty and @@is_shell
    end

    def emit(*args)
      self.class.emit(*args)
    end

    def interactive?
      self.class.interactive?
    end
  end
end
