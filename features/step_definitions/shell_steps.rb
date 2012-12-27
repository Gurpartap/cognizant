When /^the shell is running$/ do
  step %Q{I see "You are speaking to the Cognizant Monitoring Daemon." in the shell}
end

When /^the shell is not running$/ do
  step %Q{I see "Could not connect to Cognizant daemon process" in the shell}
end

When /^I run "([^"]*)" in the shell$/ do |string|
  @shell_pipe.puts(string)
  sleep 0.5
end

When /^I run "([^"]*)" successfully in the shell$/ do |cmd|
  step %Q{I run "#{cmd}" in the shell}
  step %Q{I should see "OK" in the shell}
end

# Once we have the required status, it should stay the same in the given next n seconds.
When /^the (status) of "([^"]*)" (?:should be|is) "([^"]*)" for (\d+) seconds$/ do |_, name, status, timeframe|
  step %Q{the status of "#{name}" should be "#{status}"}

  output = ""

  begin
    Timeout::timeout(timeframe.to_i) do
      catch :stop do
        loop do
          buffer = ""
          @shell_pipe.puts("status #{name}")
          while not buffer =~ /\s#{name}\s.*since/
            begin
              buffer << @shell_pipe.readpartial(1)
            rescue EOFError
              retry
            end
          end
          # We need just the line where it tells name and status.
          output = buffer.split("\n").last
          if buffer =~ /\s#{status}\s/
            # Take rest before next check.
            sleep 0.2
          else
            # Otherwise stop checking and report output in error.
            throw :stop
          end
        end
      end
    end
  rescue Timeout::Error
    # We spent the time gracefully as required.
    nil
  end

  # Successful if we reach here.
  output.should include(status)
end

When /^the (status) of "([^"]*)" (?:should be|is) "([^"]*)"$/ do |_, name, status|
  output = ""
  time_step = 0.25
  time_spent = 0
  timeout = 30
  begin
    Timeout::timeout(time_step) do
      time_spent += time_step
      @shell_pipe.puts("status #{name}")
      while not output =~ /\s#{status}\s/
        buffer = @shell_pipe.readpartial(1)
        output += buffer if buffer
      end
    end
  rescue Timeout::Error, EOFError
    retry unless time_spent > timeout
  end

  output.should include(status)
end

When /^I (?:should )?see "([^"]*)" in the shell$/ do |string|
  sleep 0.5
  output = ""

  begin
    Timeout::timeout(30) do
      while not output =~ /#{string}/
        buffer = @shell_pipe.readpartial(1)
        output += buffer if buffer
      end
    end
  rescue Timeout::Error, EOFError
    nil
  end

  output.should include(string)
end
