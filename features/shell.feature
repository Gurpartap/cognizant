Feature: Shell

  Cognizant shell provides an interactive interface to pass commands to
  the monitoring daemon.

  @shell
  Scenario: Shell should need a deamon to work
    Then the shell is not running

  @daemon
  @shell
  Scenario: Shell should realize that the daemon has gone away
    Given the daemon is running
    And the shell is running

    When I run "help" in the shell
    Then I should see "You can run the following commands" in the shell

    When the daemon is stopped
    And I run "help" in the shell
    Then I should see "Error communicating with cognizantd" in the shell
