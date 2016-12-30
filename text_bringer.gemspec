# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'text_bringer/version'

Gem::Specification.new do |spec|
  spec.name          = "text_bringer"
  spec.version       = TextBringer::VERSION
  spec.authors       = ["Shugo Maeda"]
  spec.email         = ["shugo@ruby-lang.org"]

  spec.summary       = "A text editor"
  spec.description   = "text_bringer is a text editor."
  spec.homepage      = "https://github.com/shugo/text_bringer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "curses"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "test-unit"
end
