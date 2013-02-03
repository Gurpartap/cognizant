
Cognizant.application("example") do |app|
  app.sockfile = "~/.cognizant/example/example.sock"
  app.pids_dir = "~/.cognizant/example/pids/"
  app.logs_dir = "~/.cognizant/example/logs/"
  # app.env = {}
  # app.chdir = "/apps/example/current/"
  # app.uid = "deploy1"
  # app.gid = "deploy1"

  app.monitor("redis-server-7000") do |process|
    process.autostart = true
    process.group = "redis"
    process.start_command = "/usr/local/bin/redis-server -"
    process.start_with_input = "daemonize no\nport 6666"
    process.ping_command = "redis-cli -p 6666 PING"
  end
end

Cognizant.application "example" do
  sockfile "~/.cognizant/example/example.sock"
  pids_dir "~/.cognizant/example/pids/"
  logs_dir "~/.cognizant/example/logs/"
  # env {}
  # chdir "/apps/example/current/"
  # uid "deploy1"
  # gid "deploy1"

  monitor "redis-server-7000" do
    autostart!
    group "redis"
    start_command "/usr/local/bin/redis-server -"
    start_with_input "daemonize no\nport 6666"
    ping_command "redis-cli -p 6666 PING"
  end
end
