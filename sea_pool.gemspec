require File.expand_path("../lib/sea_pool/version", __FILE__)
require 'time'

Gem::Specification.new do |s|

  s.name    = "sea_pool"
  s.version = SeaPool::VERSION
  s.summary = "C/C++ amalgamation tool"
  s.author  = "Cameron Harper"
  s.date = Date.today.to_s
  s.files = Dir.glob("lib/**/*.rb")
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.required_ruby_version = '>= 2.0'

end
