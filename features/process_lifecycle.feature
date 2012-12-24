Feature: Process Lifecycle

  Cognizant provides a number of commands to maually change the state of a
  process as a part of its maintenance.

  Background:
    Given a file named "sleep_process.rb" with:
      """ruby
      Cognizant.monitor do
        name 'sleep_process'
        start_command 'sleep 60'
        autostart false
      end
      """

  @daemon
  @shell
  Scenario: Run all maintenance commands for a sample sleep process
    Given I run "load sleep_process.rb" successfully in the shell
    And the status of "sleep_process" is "stopped"
    
    When I run "start sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "running"
    
    When I run "stop sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "stopped"
    
    When I run "restart sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "running"
    
    When I run "unmonitor sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "unmonitored"
    
    When I run "monitor sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "running"
    
    When I run "stop sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "stopped"

  @daemon
  @shell
  Scenario: Shut down the daemon via command
    When I run "shutdown" in the shell
    Then I should see "The daemon has been shutdown successfuly." in the shell
    And a process named "cognizantd" should not be running
