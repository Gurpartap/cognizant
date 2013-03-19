# Cognizant.application "redis-example-dsl" do
#   pids_dir "~/.cognizant/redis-example-dsl/pids/"
#   logs_dir "~/.cognizant/redis-example-dsl/logs/"
# 
#   monitor "redis-server-7000" do
#     autostart!
#     group "redis"
#     start_command "/usr/local/bin/redis-server -"
#     start_with_input "daemonize no\nport 6666"
#     ping_command "redis-cli -p 6666 PING"
#   end
# end

# Not using dsl for app to use some Ruby in the immediate block.
Cognizant.application "redis-example-dsl" do |app|
  app.pids_dir = "~/.cognizant/redis-example-dsl/pids/"
  app.logs_dir = "~/.cognizant/redis-example-dsl/logs/"

  # 2 slave instances to master at port 7000.
  3.times do |i|
    slaveof = i == 0 ? "" : "slaveof 127.0.0.1 7000" # Any custom code has to be outside the monitor block.

    app.monitor do
      autostart!
      name "redis-server-700#{i}"
      group "redis"
      start_command "redis-server -"
      ping_command "redis-cli -p 700#{i} PING"

      start_with_input <<-heredoc
        daemonize no
        port 700#{i}
        #{slaveof}
      heredoc

      # check :always_true, :every => 2.seconds, :times => 3 do |p|
      #   `say "Boom!"`
      # end

      check :transition, :from => :running, :to => :stopped do
        `say --rate 250 "A process has stopped!"`
      end

      check :flapping, :times => 5, :within => 30.seconds, :retry_after => 7.seconds

      check :cpu_usage, :every => 3.seconds, :above => 60.percent, :times => 3, :do => :restart
      check :memory_usage, :every => 5.seconds, :above => 100.megabytes, :times => [3, 5] do |p|
        # Send email or something.
        p.restart # Restart is the default anyways.
      end
    end
  end
end
