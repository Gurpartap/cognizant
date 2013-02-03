require "aruba/cucumber"
require "aruba/api"
require "open3"
require "fileutils"

Before "@daemon" do
  in_current_dir do
    FileUtils.mkdir("cognizant")
    File.open("cognizantd.yml", "w") do |f|
      f.write <<-heredoc
        daemonize: false
        sockfile: ./cognizant/cognizantd.sock
        pidfile: ./cognizant/cognizantd.pid
        logfile: ./cognizant/cognizantd.log
      heredoc
    end

    cmd = "cognizantd cognizantd.yml --trace"
    Aruba.config.hooks.execute(:before_cmd, self, cmd)
    announcer.dir(Dir.pwd)
    announcer.cmd(cmd)

    @daemon_pipe = IO.popen(cmd, "r")
    sleep 2
  end
end

After "@daemon" do
  ::Process.kill("TERM", @daemon_pipe.pid)
  sleep 0.5
  ::Process.kill("KILL", @daemon_pipe.pid)
end

Before "@shell" do
  in_current_dir do
    cmd = "cognizant shell --sockfile ./cognizant/cognizantd.sock"

    Aruba.config.hooks.execute(:before_cmd, self, cmd)
    announcer.dir(Dir.pwd)
    announcer.cmd(cmd)

    @shell_pipe = IO.popen(cmd, "w+")
    sleep 1
  end
end

After "@shell" do
  ::Process.kill("TERM", @shell_pipe.pid)
  sleep 0.5
  ::Process.kill("KILL", @shell_pipe.pid)
end
