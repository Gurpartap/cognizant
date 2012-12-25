Feature: Daemon

  The monitoring daemon needs to run in the background and handle process
  management and provide a command socket for interaction.

  @daemon
  Scenario: Start and stop the daemon
    When the daemon is running
    Then a process named "cognizantd" should be running

    When the daemon is stopped
    Then a process named "cognizantd" should not be running
