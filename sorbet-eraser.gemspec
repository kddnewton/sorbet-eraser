# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sorbet/eraser/version"

Gem::Specification.new do |spec|
  spec.name          = "sorbet-eraser"
  spec.version       = Sorbet::Eraser::VERSION
  spec.authors       = ["Kevin Newton"]
  spec.email         = ["kddnewton@gmail.com"]

  spec.summary       = "Erase all traces of sorbet-runtime code."
  spec.homepage      = "https://github.com/kddnewton/sorbet-eraser"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
end
