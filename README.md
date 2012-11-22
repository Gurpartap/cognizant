# Cognizant: system utility to supervise your processes

Let us say that you have a program that is critical for your application. Any
downtime for the processes of this program would hurt your business. You want
to make sure these processes are always up and working. If anything unexpected
happens to their state, you want to be notified about it.

Enter Cognizant. Cognizant is a system utility that supervises your processes,
monitoring and ensuring their state based on a flexible criteria.

In simpler terms, it keeps your processes up and running. It ensures
that something productive (like restart) is done when the process being
monitored matches a certain condition (like RAM, CPU usage or a custom
condition).

And if it matters, cognizant means "having knowledge or being aware of",
according to Apple's Dictionary.

PS: Although the core works efficiently, yet conditions, notifications, the
command interface to the utility, documentation and some other features need
a lot of work. Contributions will be overwhelmingly welcomed!

PS2: This README is written as a roadmap for the features planned for cognizant.
Some of them might not yet be implemented (e.g. conditions, notifications,
etc.).

Cognizant can be used to monitor any long running process, including the
following:

- Web servers (Nginx, Apache httpd, WebSocket, etc.)
- Databases (Redis, MongoDB, MySQL, PostgreSQL, etc.)
- Job workers (Resque, Sidekiq, Qless, etc.)
- Message queue applications (RabbitMQ, Beanstalkd, etc.)
- Logs collection daemons
- Or any other program that needs to keep running

### Monitoring

Cognizant can be used to monitor an application process' state so that it
is running at all times. When cognizant is instructed to monitor a process,
by default, the process will automatically be started. These processes are
automatically monitored for their state. i.e. a process is automatically
started again if it stops unexpectedly.

### Conditions

Conditions provide a way to monitor and act on more than just the state of a
process. For example, conditions can monitor the resource utilization (RAM,
CPU, etc.) of the application process and restart it if it matches a
condition.

### Notifications

Notifications provide a way to alert system administrator of unexpected events
happening with the process. Notifications can use multiple gateways, including
email and twitter [direct message].

## Getting started

Cognizant is written in the Ruby programming language, and hence depends on
it. Ensure that you have Ruby 1.9+ installed and run:

    $ gem install cognizant

## Architecture overview

                                                          _____
                                                 ___________   |
     ____________          ____________         |           |  |
    |            |        |            | -----> | Process A |  |
    | Admin      |        | Monitoring |        |___________|  |
    | Utility    | -----> | Daemon     |         ___________   | -- Managed Processes
    | >_         |        |            |        |           |  |
    |____________|        |____________| -----> | Process B |  |
                                                |___________|  |
                                                          _____|

Since cognizant administration and process monitoring are two separate concerns, they are serviced by separate applications, `cognizant` and `cognizantd`, respectively.

## Starting the monitoring daemon

Cognizant runs the monitoring essentials through the `cognizantd` daemon application, which also maintains a server for accepting commands from the `cognizant` administration utility.

The daemon, with it's default options, requires superuser access to certain system directories for storing logs and pid files. It can be started as follows:

    $ sudo cognizantd    # ubuntu, debian, os x, etc.
    $ su -c 'cognizantd' # amazon linux, centos, rhel, etc.

To start without superuser access, specify these file and directory config variables to where the user starting it has write access:

PS: See `examples/cognizantd.yml` for more examples.

    $ cognizantd ~/.cognizant/cognizantd.yml
    
    # assuming that:
    
    $ cat ~/.cognizant/cognizantd.yml
    ---
    socket:   ~/.cognizant/cognizantd.sock
    pidfile:  ~/.cognizant/cognizantd.pid
    logfile:  ~/.cognizant/cognizantd.log
    pids_dir: ~/.cognizant/pids/
    logs_dir: ~/.cognizant/logs/

or

    # pass config directly into the daemon's STDIN
    $ echo <<EOF | cognizantd -
    ---
    socket:   ~/.cognizant/cognizantd.sock
    pidfile:  ~/.cognizant/cognizantd.pid
    logfile:  ~/.cognizant/cognizantd.log
    pids_dir: ~/.cognizant/pids/
    logs_dir: ~/.cognizant/logs/
    
    monitor: {
      redis-server-1: {
        group: redis,
        start_command: /usr/local/bin/redis-server -,
        start_with_input: "daemonize no\nport 6666",
        ping_command: redis-cli -p 6666 PING,
        stop_signals: [TERM, INT]
      },
      redis-server-2: {
        group: redis,
        start_command: /usr/local/bin/redis-server -,
        start_with_input: "daemonize no\nport 7777",
        ping_command: redis-cli -p 7777 PING,
        stop_command: redis-cli -p 7777 SHUTDOWN
      },
      sleep-10: {
        start_command: sleep 10,
        autostart: false
      }
    }
    EOF

## Using the administration utility

Cognizant can be administered using the `cognizant` command line utility. This is an application for performing administration tasks like monitoring, starting, stopping processes or loading configuration and processes' information.

PS: Currently the following methods are not implemented. However, there's a way to manage already defined processes by using `telnet /path/to/cognizantd.sock` and then `start my-process`, etc. See `lib/cognizant/server/commands.rb` for more commands.

Here's how you tell cognizant to start monitoring new processes:

    $ cognizant load ./examples/redis-server.rb # find this file in source code

Now check status of all managed processes:

    $ cognizant status
    
    +----------------+-------+------------------------+
    | Process        | Group | State                  |
    +----------------+-------+------------------------+
    | redis-server-1 | redis | running since 1 minute |
    +----------------+-------+------------------------+
    | redis-server-2 | redis | running since 1 minute |
    +----------------+-------+------------------------+
    2012-11-23 01:16:18 +0530

## Contributing

Contributions are definitely welcome. To contribute, just follow the usual
workflow:

1. Fork Cognizant
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Github pull request

## Compatibility

Cognizant was developed and tested under Ruby 1.9.2-p290.

## Similar programs

- Monit
- God (Ruby)
- Bluepill (Ruby)
- Supervisord (Python)
- Upstart
- SysV Init
- Systemd
- Launchd

### Links

- Documentation: http://rubydoc.info/github/Gurpartap/cognizant/frames
- Source: https://github.com/Gurpartap/cognizant
- Rubygems: https://rubygems.org/gems/cognizant

## About

Cognizant is a project of [Gurpartap Singh](http://gurpartap.com/). Feel free
to get in touch.
