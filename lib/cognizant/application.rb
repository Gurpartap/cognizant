require "eventmachine"

require "cognizant/controller"
require "cognizant/interface"
require "cognizant/system"
require "cognizant/application/dsl_proxy"

module Cognizant
  def self.application(application_name = nil, attributes = {}, &block)
    Cognizant::Controller.daemon.create_application(application_name, attributes, &block)
  end

  class Application
    attr_accessor :name, :sockfile, :pids_dir, :logs_dir
    attr_accessor :socket, :processes

    def initialize(name = nil, options = {}, &block)
      self.load({ name: name }.merge(options), &block)
    end

    def load(options = {}, &block)
      self.reset!

      set_attributes(options)

      if block
        if block.arity == 0
          dsl_proxy = Cognizant::Application::DSLProxy.new(self, &block)
          set_attributes(dsl_proxy.attributes)
        else
          instance_exec(self, &block)
        end
      end

      raise "Application name is missing. Aborting." unless self.name
      raise "Application processes are missing. Aborting." unless self.processes.keys.size > 0

      self.setup_directories
      self.start_socket
    end

    def set_attributes(attributes)
      procs = {}
      procs = attributes.delete(:processes) if attributes.has_key?(:processes)

      mons = {}
      mons = attributes.delete(:monitor) if attributes.has_key?(:monitor)

      # Attributes.
      attributes.each do |key, value|
        self.send("#{key}=", attributes.delete(key)) if self.respond_to?("#{key}=")
      end

      # Processes.
      procs.each do |key, value|
        process(key, value)
      end

      # Automatically monitor these.
      mons.each do |key, value|
        monitor(key, value)
      end
    end

    def monitor(process_name = nil, attributes = {}, &block)
      proc = create_process(process_name, attributes, &block)
      proc.monitor
      proc
    end

    def process(process_name = nil, attributes = {}, &block)
      create_process(process_name, attributes, &block)
    end

    def reset!
      self.stop_previous_socket

      self.name      = nil
      self.sockfile  = nil
      self.pids_dir  = nil
      self.logs_dir  = nil
      self.processes.values.each(&:reset!) if self.processes.is_a?(Hash)
      self.processes = {}
    end

    def shutdown!
      EventMachine.stop_server(@socket_signature)
      # Give the server some time to shutdown.
      EventMachine.add_timer(0.1) do
        reset!
      end
    end

    def sockfile
      if @sockfile and expanded_path = File.expand_path(@sockfile)
        expanded_path
      else
        "/var/run/cognizant/#{self.name}/#{self.name}.sock"
      end
    end

    def pids_dir
      if @pids_dir and expanded_path = File.expand_path(@pids_dir)
        expanded_path
      else
        "/var/run/cognizant/#{self.name}/pids/"
      end
    end

    def logs_dir
      if @logs_dir and expanded_path = File.expand_path(@logs_dir)
        expanded_path
      else
        "/var/log/cognizant/#{self.name}/logs/"
      end
    end

    def create_process(process_name, options = {}, &block)
      p = Cognizant::Process.new(process_name, options, &block)
      p.instance_variable_set(:@application, self)
      self.processes[p.name.to_sym] = p
      p
    end

    def tick
      self.processes.values.each(&:tick)
    end

    def start_socket
      @socket_signature = EventMachine.start_unix_domain_server(self.sockfile, Cognizant::Interface)
    end

    def stop_previous_socket
      # Socket isn't actually owned by anyone.
      begin
        sock = UNIXSocket.new(self.sockfile)
      rescue Errno::ECONNREFUSED
        # This happens with non-socket files and when the listening
        # end of a socket has exited.
      rescue Errno::ENOENT
        # Socket doesn't exist.
        return
      else
        # Rats, it's still active.
        sock.close
        raise Errno::EADDRINUSE.new("Another process or application is likely already listening on the socket at #{self.sockfile}.")
      end
    
      # Socket should still exist, so don't need to handle error.
      stat = File.stat(self.sockfile)
      unless stat.socket?
        raise Errno::EADDRINUSE.new("Non-socket file present at socket file path #{self.sockfile}. Either remove that file and restart Cognizant, or change the socket file path.")
      end
    
      Log[self].info("Blowing away old socket file at #{self.sockfile}. This likely indicates a previous Cognizant application which did not shutdown gracefully.")

      # Whee, blow it away.
      unlink_sockfile
    end

    def setup_directories
      # Create the require directories.
      Cognizant::System.mkdir(self.pids_dir, self.logs_dir, File.dirname(self.sockfile))
    end

    def unlink_sockfile
      Cognizant::System.unlink_file(self.sockfile) if self.sockfile
    end
  end
end
