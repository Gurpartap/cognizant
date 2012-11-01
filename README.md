# Cognizant

Cognizant is a system utility that supervises your processes, ensuring their
state based on a flexible criteria.

In simpler terms, cognizant keeps your processes up and running. It ensures
that something productive (like restart) is done when the process being
monitored matches a certain condition (like RAM, CPU usage or a custom
condition).

PS: Although the core works efficiently, yet the command interface to the
utility, documentation and some other features need a lot of work.
Contributions will be overwhelmingly welcomed!

PS2: This README is written as a roadmap for the features cognizant would
ideally provide. Some of them might not yet be implemented (e.g. conditions).

Cognizant can be used to monitor any long running process, including the
following examples:

- Web servers (Nginx, Apache httpd, WebSocket, etc.)
- Databases (Redis, MongoDB, MySQL, PostgreSQL, etc.)
- Job workers (Resque, Sidekiq, etc.)
- Message queue applications (RabbitMQ, Beanstalkd, etc.)
- Logs collection daemon
- Or any other program that needs to keep running

## Links

Documentation: http://rubydoc.info/github/Gurpartap/cognizant/frames
Github (source): https://github.com/Gurpartap/cognizant
Rubygems: https://rubygems.org/gems/cognizant

## Monitoring

Cognizant can be used to monitor an application process' state so that it
is running at all times. When cognizant is instructed to monitor a process,
by default, the process will automatically be started. These processes are
automatically monitored for their state. i.e. a process is automatically
started again if it stops unexpectedly.

## Conditions

Conditions provide a way to monitor and act on more than just the state of a
process. For example, conditions can monitor the resource utilization (RAM,
CPU, etc.) of the application process and restart it if it matches a
condition.

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
    EOF

## Using the administration utility

Cognizant can be administered using the `cognizant` command line utility. This is an application for performing administration tasks like monitoring, starting, stopping processes or loading configuration and processes' information.

PS: Currently the following methods are not implemented. However, there's a way to manage already defined processes by using `telnet /path/to/cognizantd.sock` and then `start my-process`, etc. See `lib/cognizant/server/commands.rb` for more commands.

Here's how you tell cognizant to start monitoring a new process:

    $ cognizant monitor --name          resque-worker-1                \
                        --group         resque                         \
                        --chdir         /apps/example/current/         \
                        --start_command "bundle exec rake resque:work"

Now check it's status:

    $ cognizant status resque-worker-1
    ---
    resque-worker-1: {
      state: running,
      uptime: 3600 # 1 hour
    }

Or check status of all processes:

    $ cognizant status resque-worker-1
    ---
    redis-server: {
      state: running,
      uptime: 5400 # 1 hour 30 minutes
    },
    resque-worker-1: {
      group: resque,
      state: running,
      uptime: 3600 # 1 hour
    },
    resque-worker-2: {
      group: resque,
      state: stoppped,
      uptime: 0
    }

### Works anywhere

Cognizant can be used on any operating system where Ruby 1.9+ works.

### What are the other programs similar to cognizant?

- Monit
- God (Ruby)
- Bluepill (Ruby)
- Supervisord (Python)
- Upstart
- SysV Init
- Systemd
- Launchd

### Which one of these should I be using?

The one that gets your job done efficiently.

### What does the term "cognizant" mean?

If it matters, cognizant means "having knowledge or being aware of", according to Apple's Dictionary.
