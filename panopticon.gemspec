# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'panopticon/version'

Gem::Specification.new do |spec|
  spec.name          = "panopticon"
  spec.version       = Panopticon::VERSION
  spec.authors       = ["enukane"]
  spec.email         = ["enukane@glenda9.org"]

  spec.summary       = %q{Wi-Fi packet capture software set on Raspberry Pi }
  spec.homepage      = "https://github.com/enukane/panopticon"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_dependency 'pidfile', "~> 0.3.0"
  spec.add_dependency 'sinatra', "~> 1.4.7"
end
