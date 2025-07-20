# frozen_string_literal: true

require_relative "lib/fiber_job/version"

Gem::Specification.new do |spec|
  spec.name = "fiber_job"
  spec.version = FiberJob::VERSION
	spec.authors = ["Caio Mendonca"]
  spec.summary = "Experimental High-performance, Redis-based background job processing library for Ruby built on fiber-based concurrency"
  spec.homepage = "https://github.com/caieras/fiber_job"
  spec.license = "MIT"

	spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = "https://github.com/caieras/fiber_job"
  spec.metadata["changelog_uri"] = "https://github.com/caieras/fiber_job/blob/main/CHANGELOG.md"

  spec.files = Dir["{lib}/**/*", "*.md", base: __dir__]

  # Dependencies
  spec.add_dependency "async", "~> 2.26.0"
  spec.add_dependency "redis", "~> 5.4.1"
end
