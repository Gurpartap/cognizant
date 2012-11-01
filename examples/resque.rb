5.times do |i|
  Cognizant.monitor "resque-worker-#{i}" do |process|
    process.group         = "resque"
    process.uid           = "deploy"
    process.gid           = "deploy"
    process.chdir         = "/apps/example/current/"
    process.env           = { "QUEUE" => "*", "RACK_ENV" => "production" }
    process.start_command = "bundle exec rake resque:work"
  end
end
