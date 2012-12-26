When /^the daemon is running$/ do
  step %Q{I see "Cognizant Daemon running successfully." on the daemon terminal}
end

When /^the daemon is stopped$/ do
  Process.kill("TERM", @daemon_pipe.pid)
  sleep 1
  Process.kill("KILL", @daemon_pipe.pid)
end

When /^I (?:should )?see "([^"]*)" on the daemon terminal$/ do |string|
  output = ""

  begin
    Timeout::timeout(30) do
      while not output =~ /#{string}/
        output += @daemon_pipe.readpartial(1)
      end
    end
  rescue Timeout::Error, EOFError
    nil
  end

  output.should include(string)
end
