# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'textbringer/version'

Gem::Specification.new do |spec|
  spec.name          = "textbringer"
  spec.version       = Textbringer::VERSION
  spec.authors       = ["Shugo Maeda"]
  spec.email         = ["shugo@ruby-lang.org"]

  spec.summary       = "An Emacs-like text editor"
  spec.description   = "Textbringer is a member of a demon race that takes on the form of an Emacs-like text editor."
  spec.homepage      = "https://github.com/shugo/textbringer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.4'

  spec.add_runtime_dependency "curses", ">= 1.2.7"
  spec.add_runtime_dependency "unicode-display_width", "~> 1.1"
  spec.add_runtime_dependency "clipboard", "~> 1.1"
  spec.add_runtime_dependency "fiddley", ">= 0.0.5"
  spec.add_runtime_dependency "editorconfig"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "test-unit"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "codecov"
  spec.add_development_dependency "ripper-tags"
end
