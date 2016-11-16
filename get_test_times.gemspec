Gem::Specification.new do |gem|
  gem.name        = 'get_test_times'
  gem.version     = '0.0.1'
  gem.date        = '2016-10-09'
  gem.summary     = "Get test times"
  gem.description = "Get test times"
  gem.authors     = ["James Coles-Nash"]
  gem.email       = 'james.coles-nash@clio.com'

  gem.files       = Dir["lib/**/*", "bin/*"]
  gem.executables = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.homepage    = 'http://rubygems.org/gems/get_test_times'
  gem.license       = 'MIT'
end
