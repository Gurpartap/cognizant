Feature: Flapping Check

  Here I want to test proper handling of flapping check.

  Background:
    Given a file named "monitor.rb" with:
      """ruby
      Cognizant.application 'sleep_app' do
        pids_dir './cognizant/pids/'
        logs_dir './cognizant/logs/'
        monitor 'sleep_process' do
          autostart false
          daemonize!
          start_command 'sleep 8'
          check :flapping, times: 3, within: 1.minute, retry_after: 15.seconds, retries: 0
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
    # Give 3 seconds grace time for process states to be realized by daemon.
    Then the status of "sleep_process" should be "running" for 5 seconds
    # TODO: The process goes through another stopped -> running cycle
    # before being unmonitored. Add step to handle this.
    Then the status of "sleep_process" should be "unmonitored" for 12 seconds
    Then the status of "sleep_process" should be "running" for 5 seconds

    When I run "stop sleep_process" successfully in the shell
    Then the status of "sleep_process" should be "stopped"
