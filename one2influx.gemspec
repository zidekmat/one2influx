Gem::Specification.new do |s|
  s.name        = 'one2influx'
  s.version     = '0.0.1'
  s.summary     = 'Daemon for getting monitoring data from OpenNebula\'s ' +
      'XML-RPC API and storing them to InfluxDB.'
  s.description = 'Daemon for getting monitoring data from OpenNebula\'s ' +
      'XML-RPC API and storing them to InfluxDB.'
  s.authors     = ['Matej Zidek']
  s.email       = 'zidek.matej@gmail.com'
  s.homepage    = 'http://rubygems.org/gems/hola'
  s.license     = 'Apache License 2.0'


  s.files       = Dir.glob('{bin,lib}/**/*')
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths         = ['lib']
  s.required_ruby_version = '>= 2.0.0'


  s.add_runtime_dependency 'opennebula', '~> 4.12'
  s.add_runtime_dependency 'nokogiri', '~> 1.6'
  s.add_development_dependency 'gyoku', '~> 1.3'
  s.add_development_dependency 'rubystats', '~> 0.2'

end