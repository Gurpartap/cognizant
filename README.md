# Cognizant

Cognizant keeps your processes up and running by monitoring over their state and resource utilization efficiently.

## Getting started

Install cognizant

    $ gem install cognizant

Cognizant runs the monitoring essentials through the `cognizantd` daemon application, which also maintains a TCP server (or a UNIX domain server) for accepting commands from and communicating with the `cognizant` utility.

The daemon, with it's default options, requires superuser access to certain system directories for storing logs and pid files. It can be, as such, started on Debian based systems as follows:

    $ sudo cognizant

If you wish to start without giving superuser access, you may do it as such by specifying files and directories where the user has access to write exclusively:

    $ cognizantd --socket   ~/.cognizant/cognizantd.sock \
                 --pidfile  ~/.cognizant/cognizantd.pid  \
                 --logfile  ~/.cognizant/cognizantd.log  \
                 --pids-dir ~/.cognizant/pids/           \
                 --logs-dir ~/.cognizant/logs/

or

    $ echo <<EOF | cognizantd -
      socket   ~/.cognizant/cognizantd.sock
      pidfile  ~/.cognizant/cognizantd.pid
      logfile  ~/.cognizant/cognizantd.log
      pids-dir ~/.cognizant/pids/
      logs-dir ~/.cognizant/logs/
    EOF

## Using with `cognizant`

Cognizant can be administered using the `cognizant` command line utility. Here's how you tell cognizant to start monitoring a new process:

    $ cognizant process --name resque-worker-1                 \
                        --group resque                         \
                        --chdir /apps/example/current/         \
                        --start "bundle exec rake resque:work"

