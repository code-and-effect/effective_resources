$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'effective_resources/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'effective_resources'
  s.version     = EffectiveResources::VERSION
  s.email       = ['info@codeandeffect.com']
  s.authors     = ['Code and Effect']
  s.homepage    = 'https://github.com/code-and-effect/effective_resources'
  s.summary     = 'Make any controller an effective resource controller.'
  s.description = 'Make any controller an effective resource controller.'
  s.licenses    = ['MIT']

  s.files = Dir['{app,config,db,lib}/**/*'] + ['MIT-LICENSE', 'README.md']

  s.add_dependency 'rails', '>= 4.0.0'

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "effective_bootstrap"
  s.add_development_dependency "effective_datatables"
  s.add_development_dependency "haml"
  s.add_development_dependency "pry-byebug"
  s.add_development_dependency "wicked"
  s.add_development_dependency "holidays"
  s.add_development_dependency "psych"
  s.add_development_dependency "net-smtp"
end
