require "aruba/api"

When /^I run (cognizant) `([^`]*)`$/ do |_, cmd|
  cmd = "cognizant #{cmd} --socket ./cognizant/cognizantd.sock"
  step "I run `#{cmd}`"
end

When /^a process named "([^"]*)" (?:should be|is) running$/ do |name|
  `ps -eo comm | grep ^#{name}`.size.should > 0
end

When /^a process named "([^"]*)" (?:should not be|is not) running$/ do |name|
  `ps -eo comm | grep ^#{name}`.size.should == 0
end
