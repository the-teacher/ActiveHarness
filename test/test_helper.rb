$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_harness"
require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
