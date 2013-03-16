5.times do |i|
  Cognizant.application("my-web-app") do |app|
    app.monitor "resque-worker-#{i}" do |process|
      process.group         = "resque"
      process.uid           = "deploy"
      process.gid           = "deploy"
      process.chdir         = "/apps/example/current/"
      process.env           = { "QUEUE" => "*", "RACK_ENV" => "production" }
      process.start_command = "bundle exec rake resque:work"

      process.monitor_children do
        check :memory_usage, :every => 5.seconds, :above => 100.megabytes, :times => [2, 3], :do => :stop
        stop_signals ["TERM", "INT", "KILL"]
      end
    end
  end
end
