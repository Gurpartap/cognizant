# 4 slave instances to master at port 6000.
5.times do |i|
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
  end
end
