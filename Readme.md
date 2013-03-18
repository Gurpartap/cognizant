![Cognizant](http://f.cl.ly/items/442w3l1n0i3V41220g0z/cognizant.png)

Simple and reliable process monitoring framework written in Ruby

[![Build Status](https://travis-ci.org/Gurpartap/cognizant.png?branch=master)](https://travis-ci.org/Gurpartap/cognizant) [![Gem Version](https://badge.fury.io/rb/cognizant.png)](http://badge.fury.io/rb/cognizant) [![Dependency Status](https://gemnasium.com/Gurpartap/cognizant.png)](https://gemnasium.com/Gurpartap/cognizant) [![Code Climate](https://codeclimate.com/github/Gurpartap/cognizant.png)](https://codeclimate.com/github/Gurpartap/cognizant)

## Quick start

###### Install Cognizant
```bash
$ gem install cognizant
```

###### Example thin server configuration
```bash
$ vim /etc/cognizantd/apps/thin_cluster.cz
```

```ruby
app_root = "/apps/acmecorp.com"
servers = 5
port = 4000

Cognizant.application 'acmecorp.com' do |app|
  servers.times do |n|
    app.monitor "thin-#{n}" do
      autostart!      
      group 'thin'
      uid 'www-data'
      gid 'www-data'

      env RACK_ENV: "production"
      chdir "#{app_root}/current"

      daemonize false
      pidfile "#{app_root}/shared/tmp/pids/thin.400#{n}.pid"

      start_command   "bundle exec thin start   --only #{n} --servers #{servers} --port #{port}"
      stop_command    "bundle exec thin stop    --only #{n} --servers #{servers} --port #{port}"
      restart_command "bundle exec thin restart --only #{n} --servers #{servers} --port #{port}"

      check :cpu_usage,    :above => 50.percent,    :every => 5.seconds, :times => 5,      :do => :restart
      check :memory_usage, :above => 300.megabytes, :every => 5.seconds, :times => [3, 5], :do => :restart
    end
  end
end
```

**YAML** version of this example is [available in the wiki](https://github.com/Gurpartap/cognizant/wiki/Thin-Server-Cluster).

###### Start the daemon and load the configuration
```bash
$ cognizantd
$ cognizant load thin_cluster.cz
```

###### Enter the Cognizant shell and view the status of managed processes
```bash
$ cognizant
Welcome Gurpartap! You are speaking to the Cognizant Monitoring Daemon.
Enter 'help' if you're not sure what to do.

Type 'quit' or 'exit' to quit at any time.
> use acmecorp.com
OK
```

```
(acmecorp.com)> status
+---------+-------+------------------------+-------+-------+--------+
| Process | Group | State                  | PID   | % CPU | Memory |
+---------+-------+------------------------+-------+-------+--------+
| thin-0  | thin  | running since 1 minute | 59825 | 0.0   | 47 MiB |
+---------+-------+------------------------+-------+-------+--------+
| thin-1  | thin  | running since 1 minute | 59828 | 0.0   | 47 MiB |
+---------+-------+------------------------+-------+-------+--------+
| thin-2  | thin  | running since 1 minute | 59829 | 0.0   | 47 MiB |
+---------+-------+------------------------+-------+-------+--------+
2013-03-18 10:00:29 +0530
```

## Further information
Cognizant has an [**extensively documented wiki**](https://github.com/Gurpartap/cognizant/wiki) for that.

## About

Cognizant is a project of [Gurpartap Singh](http://gurpartap.com/). Feel free to get in touch.
