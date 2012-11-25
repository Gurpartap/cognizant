# Cognizant: system utility to supervise your processes

Let us say that you have a program that is critical for your application. Any
downtime for the processes of this program would hurt your business. You want
to make sure these processes are always up and working. If anything unexpected
happens to their state, you want it to be fixed, and to be notified about it.

Enter Cognizant. Cognizant is a system utility that supervises your processes,
monitoring and ensuring their state based on a flexible criteria.

In simpler terms, it keeps your processes up and running. It also ensures
that something (like restart) is done when the process being monitored matches
a certain condition (like CPU usage, memory usage or a custom condition).

Cognizant can be used to monitor any long running process, including the
following commonly used programs:

- Web servers (Nginx, Apache httpd, WebSocket, etc.)
- Databases (Redis, MongoDB, MySQL, PostgreSQL, etc.)
- Job workers (Resque, Sidekiq, Qless, etc.)
- Message queue applications (RabbitMQ, Beanstalkd, etc.)
- Logs collection daemons
- Or any other program that needs to keep running

And if it matters, cognizant means "having knowledge or being aware of",
according to Apple's Dictionary.

## Features

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

See examples for conditions usage.

### Notifications

Note: Notifications are not currently implemented.

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
     `cognizant`           `cognizantd`         |___________|  |
                                                          _____|

Since cognizant administration and process monitoring are two separate
concerns, they are serviced by separate applications, `cognizant` and
`cognizantd`, respectively.

## Starting the monitoring daemon

Cognizant runs the monitoring essentials through the `cognizantd` daemon
application, which also maintains a server for accepting commands from the
`cognizant` administration utility.

The daemon, with it's default options, requires superuser access to certain
system directories for storing logs and pid files. It can be started as
follows:

    $ sudo cognizantd    # On ubuntu, debian, os x, etc.
    $ su -c 'cognizantd' # On amazon linux, centos, rhel, etc.

To start without superuser access, specify these file and directory config
variables to where the user starting it has write access:

    $ cognizantd ./examples/cognizantd.yml # YAML formatted.
    # Find this file in source code for a detailed usage example.

Assuming
    
    $ cat ./examples/cognizantd.yml # gives:
    ---
    socket:   ~/.cognizant/cognizantd.sock
    pidfile:  ~/.cognizant/cognizantd.pid
    logfile:  ~/.cognizant/cognizantd.log
    pids_dir: ~/.cognizant/pids/
    logs_dir: ~/.cognizant/logs/

Or

    # Pass config directly into the daemon's STDIN.
    $ echo <<EOF | cognizantd -
    ---
    socket:   ~/.cognizant/cognizantd.sock
    ...
    monitor: {
      ...
      ...
    }
    EOF

### Preload process information

To specify processes to be managed, the following may be specified in the
daemon's config file:

    # see examples/cognizantd.yml
    ---
    monitor: {
      redis-server-1: {
        group: redis,
        start_command: /usr/local/bin/redis-server -,
        start_with_input: "daemonize no\nport 6666",
        ping_command: redis-cli -p 6666 PING,
        stop_signals: [TERM, INT],
        checks: {
          memory_usage: {
            every: 5, # Seconds.
            above: 1048576, # Bytes.
            times: [3, 5], # Three out of five times.
            do: restart
          }
        }
      },
      sleep: {
        start_command: sleep 3,
        checks: {
          flapping: {
            times: 4,
            within: 15, # Seconds.
            retry_after: 30 # Seconds.
          }
        }
      }
    }

Process information can also be provided via Ruby code. See `cognizant load`
command in the administration utility.

All of the available options and commands for `cognizantd` are:

    $ cognizantd --help
    
    NAME
        cognizantd - system utility daemon to supervise your processes

    SYNOPSIS:
        cognizantd [GLOBAL OPTIONS] [CONFIG FILE | -]

    GLOBAL OPTIONS:
            --[no-]daemonize        Whether or not to daemonize cognizantd into background.
            --pidfile FILE          The pid (process identifier) lock file for the daemon.
            --logfile FILE          The file to log the daemon's operational information into.
            --loglevel LEVEL        The level of information to log.
            --env ENV               Environment variables for managed processes to inherit.
            --chdir DIRECTORY       The current working directory for the managed processes to start with.
            --umask UMASK           Permission mode limitations for file and directory creation.
            --user USER             Run the daemon and managed processes as the given user.
            --group GROUP           Run the daemon and managed processes as the given user group.
            --pids-dir DIRECTORY    Directory to store the pid files of managed processes, when required.
            --logs-dir DIRECTORY    Directory to store the log files of managed processes, when required.
        -s, --socket FILE           The socket lock file for the server
        -b, --bind-address ADDR     The interface to bind the TCP server to.
        -p, --port PORT             The TCP port to start the server with.
            --username USERNAME     Username for securing server access.
            --password PASSWORD     Password to accompany the username.
        -t, --trace                 Turn on tracing, enable full backtrace.
        -v, --version               Print the version number and exit.

## Using the administration utility

Cognizant can be administered using the `cognizant` command line utility. This
is an application for performing administration tasks like monitoring,
starting, stopping processes or loading configuration and processes'
information.

Here are some basic operational commands:

    $ cognizant monitor redis # by group name
    $ cognizant restart redis-server-1 # by process name

To get cognizant to ignore a particular process' state:

    $ cognizant unmonitor sleep-10

Now check status of all managed processes:

    $ cognizant status
    +----------------+-------+--------------------------------------+-------+-------+---------+
    | Process        | Group | State                                | PID   | % CPU | Memory  |
    +----------------+-------+--------------------------------------+-------+-------+---------+
    | redis-server-1 | redis | running since 1 minute               | 23442 | 10.70 | 3.7 MB  |
    +----------------+-------+--------------------------------------+-------+-------+---------+
    | redis-server-2 | redis | running since 2 minutes              | 23444 | 0.0   | 1.7 MB  |
    +----------------+-------+--------------------------------------+-------+-------+---------+
    | sleep-10       |       | unmonitored since less than a minute |       | 0.0   | 0 Bytes |
    +----------------+-------+--------------------------------------+-------+-------+---------+
    2012-11-23 01:16:18 +0530

Here's how you tell cognizant to start monitoring new processes:

    $ cognizant load ./examples/redis-server.rb
    # Find this file in source code.

All of the available options and commands for `cognizant` are:

    $ cognizant --help
    
    NAME
        cognizant - administration utility for cognizantd
    
    SYNOPSIS
        cognizant [GLOBAL OPTIONS] COMMAND [ARGUMENTS...]
    
    GLOBAL OPTIONS
        -s, --socket FILE          The socket lock file of the daemon server (default: /var/run/cognizant/cognizantd.sock)
        -b, --bind-address ADDR    The server address of the daemon server (default: none)
        -p, --port PORT            The server port of the daemon server (default: none)
            --username USERNAME    Username to use for authentication with server (default: none)
            --password PASSWORD    Password to use for authentication with server (default: none)
        -v, --version              Print the version number and exit
        -t, --trace                Turn on tracing, enabling full backtrace
            --help                 Show this message
    
    COMMANDS
        help [COMMAND]    Shows a list of commands or help for one command
        status  [NAME]    Display status of managed process(es) or group(s)
        load      FILE    Loads the process information from specified Ruby file
        monitor   NAME    Monitor the specified process or group
        unmonitor NAME    Unmonitor the specified process or group
        start     NAME    Start the specified process or group
        stop      NAME    Stop the specified process or group
        restart   NAME    Restart the specified process or group
        shutdown          Stop the monitoring daemon without affecting processes

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

- God (Ruby)
- Bluepill (Ruby)
- Supervisord (Python)
- Monit
- Upstart
- Systemd
- Launchd
- SysV Init

### Links

- Documentation: http://rubydoc.info/github/Gurpartap/cognizant/frames
- Source: https://github.com/Gurpartap/cognizant
- Rubygems: https://rubygems.org/gems/cognizant

## About

Cognizant is a project of [Gurpartap Singh](http://gurpartap.com/). Feel free
to get in touch.
