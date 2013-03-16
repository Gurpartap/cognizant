Feature: Flapping Check

  Here I want to test proper handling of flapping check.

  Background:
    Given a file named "monitor.rb" with:
      """ruby
      Cognizant.application 'sleep_app' do
        pids_dir './cognizant/pids/'
        logs_dir './cognizant/logs/'
        monitor 'sleep_process' do
          start_command 'sleep 5'
          autostart false
          check :flapping, times: 3, within: 30, retry_after: 15, retries: 0
        end
      end
      """

  @daemon
  @shell
  Scenario: Handle a process that restarts every 3 seconds
    Given the daemon is running
    And the shell is running

    When I run "load monitor.rb" successfully in the shell
    And I run "use sleep_app" successfully in the shell
    Then the status of "sleep_process" should be "stopped"

    When I run "start sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "running"
    Then the status of "sleep_process" should be "unmonitored" for 10 seconds
    Then the status of "sleep_process" should be "running"

    When I run "stop sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "stopped"
