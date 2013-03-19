Feature: Commands

  Cognizant provides a number of commands to maually change the state of a
  process as a part of its maintenance.

  Background:
    Given a file named "sleep_process.cz" with:
      """ruby
      Cognizant.application 'sleep_app' do
        pids_dir './cognizant/pids/'
        logs_dir './cognizant/logs/'
        monitor 'sleep_process' do
          autostart false
          daemonize!
          start_command 'sleep 60'
        end
      end
      """

  @daemon
  @shell
  Scenario: Run all maintenance commands for a sample sleep process
    Given the daemon is running
    And the shell is running

    When I run "load sleep_process.cz" successfully in the shell
    And I run "use sleep_app" successfully in the shell
    Then the status of "sleep_process" is "stopped"

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
  Scenario: Run the help command
    Given the daemon is running
    And the shell is running

    When I run "help" in the shell
    Then I should see "You can run the following commands" in the shell

  @daemon
  @shell
  Scenario: Shut down the daemon via command
    Given the daemon is running
    And the shell is running

    When I run "shutdown" in the shell
    Then I should see "The daemon has been shutdown successfuly." in the shell
    And a process named "cognizantd" should not be running
