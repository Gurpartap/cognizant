# 2 slave instances to master at port 6000.
3.times do |i|
  Cognizant.monitor "redis-server-600#{i}" do |process|
    process.group         = "redis"
    # process.uid           = "redis"
    # process.gid           = "redis"
    process.start_command = "redis-server -"
    process.ping_command  = "redis-cli -p 600#{i} PING"

    slaveof = i == 0 ? "" : "slaveof 127.0.0.1 6000"
    process.start_with_input = <<-heredoc
      daemonize no
      port 600#{i}
      #{slaveof}
    heredoc

    # process.on :always_true, :every => 2.seconds, :times => 3 do |p|
    #   `say "Boom!"`
    # end

    process.on :cpu_usage, :above => 60, :every => 3.seconds, :times => 3, :do => :restart

    process.on :memory_usage, :above => 100.megabytes, :every => 5.seconds, :times => [3, 5] do |p|
      p.restart # Restart is the default anyways.
    end
  end
end
