# -*- ruby -*-

require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

$:.push 'lib'
require 'queryparser'

PKG_NAME    = 'queryparser'
PKG_VERSION = QueryParser::VERSION

spec = Gem::Specification.new do |s|
  s.name              = PKG_NAME
  s.version           = PKG_VERSION
  s.summary           = 'Parse a natural language query into lucene query syntax'

  s.files             = FileList['README', 'COPY*', 'Rakefile', 'lib/**/*.rb']
  s.test_files        = FileList['test/*.rb']

  s.has_rdoc          = true
  s.rdoc_options     << '--title' << 'QueryParser' << '--charset' << 'utf-8'
  s.extra_rdoc_files  = FileList['README', 'COPYING']

  s.author            = 'Peter Hickman'
  s.email             = 'peterhi@ntlworld.com'

  s.homepage          = 'http://queryparser.rubyforge.org'
  s.rubyforge_project = 'queryparser'
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

desc "Run all the tests"
Rake::TestTask.new("test") do |t|
  t.pattern = 'test/*.rb'
  t.verbose = false
  t.warning = true
end

desc 'Generate API Documentation'
Rake::RDocTask.new('rdoc') do |rdoc| 
  rdoc.rdoc_dir = 'web/doc'
  rdoc.rdoc_files.include('lib/*.rb')  
  rdoc.options << "--all"
end
