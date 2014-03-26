$:.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'enum_table/version'

Gem::Specification.new do |gem|
  gem.name          = 'enum_table'
  gem.version       = EnumTable::VERSION
  gem.authors       = ['George Ogata']
  gem.email         = ['george.ogata@gmail.com']
  gem.license       = 'MIT'
  gem.date          = Time.now.strftime('%Y-%m-%d')
  gem.summary       = "Enumeration tables for ActiveRecord"
  gem.homepage      = 'http://github.com/howaboutwe/enum_table'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.add_runtime_dependency 'activerecord', '>= 3', '< 5'
  gem.add_development_dependency 'ritual', '~> 0.4.1'
end
