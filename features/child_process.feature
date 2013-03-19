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
    Given a file named "monitor.cz" with:
      """ruby
      Cognizant.application 'child_process_app' do
        pids_dir './cognizant/pids/'
        logs_dir './cognizant/logs/'
        monitor 'fork_machine' do
          autostart false
          daemonize!
          start_command 'ruby ./fork_machine.rb'
          stop_signals ['TERM']
          monitor_children do
            check :memory_usage, :every => 2.seconds, :above => 10.megabytes, :times => 3, :do => :stop
            stop_signals ['INT']
          end
        end
      end
      """

  @daemon
  @shell
  Scenario: Check child process memory usage
    Given the daemon is running
    And the shell is running

    When I run "load monitor.cz" successfully in the shell
    And I run "use child_process_app" successfully in the shell
    Then the status of "fork_machine" should be "stopped"

    When I run "start fork_machine" successfully in the shell
    Then the status of "fork_machine" should be "running"

    And the status of "fork_machine" should be "stopped"
