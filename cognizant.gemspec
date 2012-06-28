# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cognizant/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Gurpartap Singh"]
  gem.email         = ["contact@gurpartap.com"]
  gem.description   = "Advanced resource efficient process monitoring"
  gem.summary       = "Cognizant is an advanced process monitoring framework with a server-client model."
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "cognizant"
  gem.require_paths = ["lib"]
  gem.version       = Cognizant::VERSION

  gem.add_development_dependency "rake"
  gem.add_development_dependency "redcarpet"
  gem.add_development_dependency "yard"

  gem.add_dependency "eventmachine"
end
