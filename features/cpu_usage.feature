Feature: CPU Usage Condition

  Here I want to test proper handling of cpu_usage condition.

  Background:
    Given a file named "consume_cpu.rb" with:
      """ruby
      require 'timeout'
      $0 = File.basename(__FILE__) # Useful identification when debugging.
      data = ''
      Timeout::timeout(60) do
        loop do
          data += '*' * 100
        end
      end
      data = nil
      """
    Given a file named "monitor.rb" with:
      """ruby
      Cognizant.application 'cpu_usage_app' do
        pids_dir './cognizant/pids/'
        logs_dir './cognizant/logs/'
        monitor 'consume_cpu' do
          start_command 'ruby ./consume_cpu.rb'
          autostart false
          check :cpu_usage, :every => 2.seconds, :above => 60, :times => [2, 3], :do => :stop
        end
      end
      """

  @daemon
  @shell
  Scenario: Check CPU usage of a process that consumes a lot of CPU
    Given the daemon is running
    And the shell is running

    When I run "load monitor.rb" successfully in the shell
    And I run "use cpu_usage_app" successfully in the shell
    Then the status of "consume_cpu" should be "stopped"

    When I run "start consume_cpu" successfully in the shell
    Then the status of "consume_cpu" should be "running"

    And the status of "consume_cpu" should be "stopped"
