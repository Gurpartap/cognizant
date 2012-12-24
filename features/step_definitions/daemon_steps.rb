When /^the daemon is started$/ do
  step %Q{I see "Cognizant Daemon running successfully." on the daemon terminal}
end

When /^the daemon is stopped$/ do
  Process.kill("KILL", @daemon_pipe.pid)
end

When /^I (?:should )?see "([^"]*)" on the daemon terminal$/ do |string|
  output = ""

  Timeout::timeout(30) do
    while not output =~ /#{string}/
      output += @daemon_pipe.gets
    end
  end

  output.should include(string)
end
