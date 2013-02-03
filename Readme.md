# Cognizant: supervise your processes
[![Build Status](https://travis-ci.org/Gurpartap/cognizant.png?branch=master)](https://travis-ci.org/Gurpartap/cognizant) [![Dependency Status](https://gemnasium.com/Gurpartap/cognizant.png)](https://gemnasium.com/Gurpartap/cognizant) [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/Gurpartap/cognizant)

Cognizant is a process management framework written in Ruby. In other words, it
is a system utility that supervises your processes, monitoring and ensuring
their state based on a customizable criteria.

Since cognizant administration, and process monitoring and automation are two
separate concerns, they are serviced by separate applications, `cognizant` and
`cognizantd`, respectively.

                                                          _____
                                                 ___________   |
     ____________          ____________         |           |  |
    |            |        |            | -----> | Process A |  |
    | Admin      | -----> | Monitoring |        |___________|  |
    | Utility    |        | Daemon     |         ___________   | -- Managed Processes
    | >_         | <----- |            |        |           |  |
    |____________|        |____________| -----> | Process B |  |
     `cognizant`           `cognizantd`         |___________|  |
                                                          _____|


## Monitoring and Automation

The `cognizantd` daemon provides continuous process monitoring, automation
through conditions and triggers, and a command socket for communication.

The daemon starts with a run loop, polling the managed processes for their
state and properties. It also provides a command socket to accept commands
through the administration utility.

### Conditions

Conditions provide actions based on any properties or criteria of a process.
For example, continuous usage of a high amount of system memory would restart
the process.

### Triggers

Triggers provide actions based on changes in state of a process. For example,
repeated restarting of a process, known as "flapping". Triggers can also be
used to notify administrators when a state changes.

## Administration

Cognizant can be administered using the `cognizant` command line utility. This
is an application for performing administration tasks like enabling monitoring,
starting, stopping processes, loading process configurations, etc.

The `cognizant` utility provides a command line interface and a shell to
administer processes. It communicates with the daemon process through its
command socket. That means the `cognizantd` daemon must already be running
before you can use the `cognizant` administration utility.

## Quick start

```bash
$ gem install cognizant
$ cognizantd --help
$ cognizant --help
```

## Documentation

Cognizant has an
[**extensively documented wiki**](https://github.com/Gurpartap/cognizant/wiki).

## About

Cognizant is a project of [Gurpartap Singh](http://gurpartap.com/). Feel free
to get in touch.
