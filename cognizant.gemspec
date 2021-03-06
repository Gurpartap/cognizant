# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cognizant/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Gurpartap Singh"]
  gem.email         = ["contact@gurpartap.com"]
  gem.description   = "Cognizant is a process management framework inspired from God and Bluepill. It supervises your processes, ensuring their state based on a flexible criteria."
  gem.summary       = "Cognizant is a process management framework inspired from God and Bluepill. It supervises your processes, ensuring their state based on a flexible criteria."
  gem.homepage      = "http://github.com/Gurpartap/cognizant"
  gem.license       = "MIT"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "cognizant"
  gem.require_paths = ["lib"]
  gem.version       = Cognizant::VERSION

  gem.add_development_dependency "rake"
  gem.add_development_dependency "ruby-graphviz"
  gem.add_development_dependency "yard"
  gem.add_development_dependency "kramdown"
  gem.add_development_dependency "aruba"

  # cognizantd
  gem.add_dependency "eventmachine"
  gem.add_dependency "state_machine"
  gem.add_dependency "activesupport"
  gem.add_dependency "logging"

  # cognizant
  gem.add_dependency "commander"
  gem.add_dependency "formatador"
end
