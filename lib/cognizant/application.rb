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
    attr_accessor :name, :pids_dir, :logs_dir
    attr_accessor :processes

    def initialize(name = nil, options = {}, &block)
      self.setup({ name: name }.merge(options), &block)
    end

    def setup(options = {}, &block)
      self.reset!

      set_attributes(options)

      handle_initialize_block(&block) if block

      raise "Application name is missing. Aborting." unless self.name
      Log[self].info "Loading application #{self.name}..."

      raise "Application processes are missing. Aborting." unless self.processes.keys.size > 0

      self.setup_directories
    end

    def handle_initialize_block(&block)
      if block.arity == 0
        dsl_proxy = Cognizant::Application::DSLProxy.new(self, &block)
        attributes = dsl_proxy.attributes
        set_attributes(attributes)
      else
        instance_exec(self, &block)
      end
    end

    def set_attributes(attributes)
      procs = {}
      procs = attributes.delete(:processes) if attributes.has_key?(:processes)

      mons = {}
      mons = attributes.delete(:monitor) if attributes.has_key?(:monitor)

      # Attributes.
      attributes.each do |key, value|
        if self.respond_to?("#{key}=")
          value = attributes.delete(key)
          self.send("#{key}=", value)
        end
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
      self.name      = nil
      self.pids_dir  = nil
      self.logs_dir  = nil
      self.processes.values.each(&:reset!) if self.processes.is_a?(Hash)
      self.processes = {}
    end
    alias :shutdown! :reset!

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

    def setup_directories
      Cognizant::System.mkdir(self.pids_dir, self.logs_dir)
    end
  end
end
