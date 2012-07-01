require "cognizant/client/interface"

module Cognizant
  def self.add_process(options)
    EventMachine.run do
      client = Cognizant::Client::Interface.new(options[:socket])
      # client[:A] = 99
      # client[:B] = 98
      # client[:C] = 97
      # client.keys   { |keys| puts "keys: #{keys}" }
      # client.values { |vals| puts "vals: #{vals}" }
    end
  end

  def self.monitor_process(*args)
    
  end

  def self.start_process(*args)
    
  end

  def self.stop_process(*args)
    
  end

  def self.restart_process(*args)
    
  end

  def self.unmonitor_process(*args)
    
  end

  def self.remove_process(*args)
    
  end
end
