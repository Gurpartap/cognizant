Feature: Memory Usage Condition

  Here I want to test proper handling of memory_usage condition.

  Background:
    Given a file named "consume_memory.rb" with:
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
      Cognizant.application 'memory_usage_app' do
        sockfile './cognizant/features.sock'
        pids_dir './cognizant/pids/'
        logs_dir './cognizant/logs/'
        monitor 'consume_memory' do
          start_command 'ruby ./consume_memory.rb'
          autostart false
          check :memory_usage, :every => 2.seconds, :above => 10.megabytes, :times => [2, 3], :do => :stop
        end
      end
      """

  @daemon
  @shell
  Scenario: Check memory usage of a process that consumes a lot of memory
    Given the daemon is running
    And the shell is running

    When I run "load monitor.rb" successfully in the shell
    And I run "use memory_usage_app" successfully in the shell
    Then the status of "consume_memory" should be "stopped"

    When I run "start consume_memory" successfully in the shell
    Then the status of "consume_memory" should be "running"

    And the status of "consume_memory" should be "stopped"
