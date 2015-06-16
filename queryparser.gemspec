# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "queryparser"

Gem::Specification.new do |spec|
  spec.name        = "queryparser"
  spec.version     = QueryParser::VERSION
  spec.authors     = ["Peter Hickman"]
  spec.email       = []
  spec.homepage    = "https://github.com/PeterHickman/QueryParser"
  spec.summary     = %q{Parse query in plain english and turn it into a Lucene query}
  spec.description = %Q{TODO}
  spec.license     = "GPL"

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9.3'
end
