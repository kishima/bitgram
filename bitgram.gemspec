# frozen_string_literal: true

require_relative "lib/bitgram/version"

Gem::Specification.new do |spec|
  spec.name = "bitgram"
  spec.version = Bitgram::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Generate packet and bit-field diagrams from YAML, JSON, or Ruby"
  spec.description = "Render declarative bit-field diagrams as ASCII, Unicode, SVG, PNG, and JPEG."
  spec.homepage = "https://github.com/ydah/bitgram"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "exe/*", "schema/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.bindir = "exe"
  spec.executables = ["bitgram"]
  spec.require_paths = ["lib"]

  spec.add_dependency "unicode-display_width", "~> 3.1"
end
