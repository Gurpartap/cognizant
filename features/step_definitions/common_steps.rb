require "aruba/api"

# When /^I run (cognizant) `([^`]*)`$/ do |_, cmd|
#   cmd = "cognizant #{cmd} --sockfile ./example"
#   step "I run `#{cmd}`"
# end

When /^a process named "([^"]*)" (?:should be|is) running$/ do |name|
  `ps -eo command | grep ^#{name}`.should include(name)
end

When /^a process named "([^"]*)" (?:should not be|is not) running$/ do |name|
  `ps -eo command | grep ^#{name}`.should_not include(name)
end
