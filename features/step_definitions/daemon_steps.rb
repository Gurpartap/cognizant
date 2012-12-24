When /^I (?:should|) see "([^"]*)" on the daemon terminal$/ do |string|
  output = ""

  Timeout::timeout(10) do
    while not output =~ /#{string}/
      output += @daemon_pipe.gets
    end
  end

  output.should include(string)
end

When /^the daemon is stopped$/ do
  Process.kill("KILL", @daemon_pipe.pid)
end
