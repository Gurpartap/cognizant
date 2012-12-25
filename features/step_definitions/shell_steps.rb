When /^the shell is running$/ do
  step %Q{I see "You are speaking to the Cognizant Monitoring Daemon." in the shell}
end

When /^I run "([^"]*)" in the shell$/ do |string|
  @shell_pipe.puts(string)
  sleep 0.5
end

When /^I run "([^"]*)" successfully in the shell$/ do |cmd|
  step %Q{I run "#{cmd}" in the shell}
  step %Q{I should see "OK" in the shell}
end

When /^the (status) of "([^"]*)" (?:should be|is) "([^"]*)"$/ do |_, name, status|
  output = ""
  time_step = 0.5
  time_spent = 0
  timeout = 30
  begin
    Timeout::timeout(time_step) do
      time_spent += time_step
      @shell_pipe.puts("status #{name}")
      while not output =~ /\s#{status}\s/
        buffer = @shell_pipe.gets
        output += buffer if buffer
      end
    end
  rescue Timeout::Error => e
    retry unless time_spent > timeout
  end

  output.should include(status)
end

When /^I (?:should )?see "([^"]*)" in the shell$/ do |string|
  sleep 0.5
  output = ""

  Timeout::timeout(30) do
    while not output =~ /#{string}/
      buffer = @shell_pipe.gets
      output += buffer if buffer
    end
  end

  output.should include(string)
end
