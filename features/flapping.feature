Feature: Flapping Check

  Here I want to test proper handling of flapping check.

  Background:
    Given a file named "monitor.rb" with:
      """ruby
      Cognizant.monitor do
        name 'sleep_process'
        start_command 'sleep 2'
        autostart false
        check :flapping, times: 2, within: 30, retry_after: 3
      end
      """

  @daemon
  @shell
  Scenario: Check flapping of for a process that restarts every 3 seconds
    Given the daemon is running
    And the shell is running

    When I run "load monitor.rb" successfully in the shell
    Then the status of "sleep_process" should be "stopped"

    When I run "start sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "running"
    Then the status of "sleep_process" should be "unmonitored"
    Then the status of "sleep_process" should be "running"

    When I run "stop sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "stopped"
