require_relative "lib/active_harness/core/version"

Gem::Specification.new do |spec|
  spec.name    = "active_harness"
  spec.version = ActiveHarness::VERSION
  spec.authors = ["the-teacher"]
  spec.summary = "DSL for describing and running AI agents with safety layers"
  spec.description = <<~DESC
    ActiveHarness provides a DSL for describing AI agents and an engine for
    their execution, with built-in prompt-injection protection (guard layer),
    provider fallback chains, and a structured result API.
  DESC
  spec.license = "MIT"

  spec.files         = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.6"

  spec.add_dependency "json", "~> 2.0"

  spec.add_development_dependency "minitest",           "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.0"
  spec.add_development_dependency "mocha",              "~> 2.0"
end
