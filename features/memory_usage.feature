Feature: Memory Usage Condition

  Here I want to test proper handling of memory_usage condition.

  Background:
    Given a file named "consume_memory.rb" with:
      """ruby
      require 'timeout'
      $0 = File.basename(__FILE__) # Useful identification when debugging.
      data = ''
      Timeout::timeout(30) do
        loop do
          data = '0' * 102400
        end
      end
      data = nil
      """
    Given a file named "monitor.rb" with:
      """ruby
      Cognizant.monitor do
        name 'consume_memory'
        start_command 'ruby ./consume_memory.rb'
        autostart false
        check :memory_usage, :every => 2.seconds, :above => 10.megabytes, :times => [2, 3], :do => :stop
      end
      """

  @daemon
  @shell
  Scenario: Check memory usage of a process that consumes a lot of memory
    When I run "load monitor.rb" successfully in the shell
    Then the status of "consume_memory" should be "stopped"
  
    When I run "start consume_memory" successfully in the shell
    Then the status of "consume_memory" should be "running"
  
    And the status of "consume_memory" should be "stopped"
