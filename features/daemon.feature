Feature: Daemon

  The monitoring daemon needs to run in the background and handle process
  management and provide a command socket for interaction.

  @daemon
  Scenario: Start and stop the daemon
    When a process named "cognizantd" is running
    Then I should see "Cognizant Daemon running successfully." on the daemon terminal

    When the daemon is stopped
    Then a process named "cognizantd" should not be running
