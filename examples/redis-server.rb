# 2 slave instances to master at port 6000.
3.times do |i|
  Cognizant.monitor("redis-server-600#{i}") do |process|
    # process.name = "redis-server-600#{i}" # Same thing as above.
    process.group = "redis"
    # process.uid = "redis"
    # process.gid = "redis"
    process.start_command = "redis-server -"
    process.ping_command = "redis-cli -p 600#{i} PING"

    slaveof = i == 0 ? "" : "slaveof 127.0.0.1 6000"
    process.start_with_input = <<-heredoc
      daemonize no
      port 600#{i}
      #{slaveof}
    heredoc

    # process.check(:always_true, :every => 2.seconds, :times => 3) do |p|
    #   `say "Boom!"`
    # end

    # :retry_after => 0 means do not retry.
    process.check(:flapping, :times => 5, :within => 30.seconds, :retry_after => 7.seconds)

    process.check(:cpu_usage, :every => 5.seconds, :above => 60, :times => [3, 5], :do => :restart)
    process.check(:memory_usage, :every => 5.seconds, :above => 100.megabytes, :times => [3, 5]) do |p|
      p.restart # Restart is the default anyways.
    end
  end
end
