# -*- encoding: utf-8 -*-
require File.expand_path('../lib/snapshot_tree/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Szetobo"]
  gem.email         = ["szetobo@gmail.com"]
  gem.homepage      = "https://github.com/szetobo/snapshot_tree"
  gem.summary       = "Mutliple snapshot hierarchical tree implementation of adjacency list using recursive query of Postgresql"
  gem.description   = "Mutliple snapshot hierarchical tree implementation of adjacency list using recursive query of Postgresql"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "snapshot_tree"
  gem.require_paths = ["lib"]
  gem.version       = SnapshotTree::VERSION

  gem.add_dependency "activerecord", ">= 3.0.0"
  gem.add_dependency "activesupport", ">= 3.0.0"
  gem.add_dependency "pg", ">= 0.11.0"
  gem.add_dependency "hbs", "~> 0.1.2"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", "~> 2.6"
  gem.add_development_dependency "guard-rspec"
  gem.add_development_dependency "pry"
end
