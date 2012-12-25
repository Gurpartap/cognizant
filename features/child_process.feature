Feature: Child Process

  Forks (children) of a process can be checked for conditions and triggers
  similar to their parent process.

  Background:
    Given a file named "fork_machine.rb" with:
      """ruby
      require 'timeout'
      $0 = File.basename(__FILE__) # Useful identification when debugging.
      children = []
      Signal.trap('TERM') do
        children.each do |child|
          Process.kill('INT', child)
        end
      end
      children << fork do
        Signal.trap 'INT' do
          exit
        end
        data = ''
        Timeout::timeout(60) do
          loop do
            data += '*' * 100
          end
        end
        data = nil
      end
      Process.waitall
      """
    Given a file named "monitor.rb" with:
      """ruby
      Cognizant.monitor do
        name 'fork_machine'
        start_command 'ruby ./fork_machine.rb'
        autostart false
        daemonize!
        stop_signals ['TERM']
        monitor_children do
          check :memory_usage, :every => 2.seconds, :above => 50.megabytes, :times => 3, :do => :stop
          stop_signals ['INT']
        end
      end
      """

  @daemon
  @shell
  Scenario: Check child process memory usage
    Given the daemon is started

    When I run "load monitor.rb" successfully in the shell
    Then the status of "fork_machine" should be "stopped"

    When I run "start fork_machine" successfully in the shell
    Then the status of "fork_machine" should be "running"

    And the status of "fork_machine" should be "stopped"
