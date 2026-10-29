# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Regenerate preset examples (set RASTER=0 to omit PNG)"
task :examples do
  require_relative "lib/bitgram"
  extensions = %w[txt svg]
  Bitgram.presets.each do |name|
    diagram = Bitgram.preset(name)
    FileUtils.cp("lib/bitgram/presets/#{name}.yml", "examples/#{name}.yml")
    extensions.each { |extension| diagram.save("examples/#{name}.#{extension}") }
    diagram.save("examples/#{name}.png") unless ENV["RASTER"] == "0"
  end
end

desc "Report rendering time for 1,000 fields"
task :benchmark do
  require_relative "lib/bitgram"
  diagram = Bitgram.load(version: 1, fields: Array.new(1000) { |i| { name: "Field #{i}", bits: 32 } })
  %i[layout to_ascii to_svg].each do |operation|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    diagram.public_send(operation)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    puts format("%<operation>s: %<time>.1f ms", operation: operation, time: elapsed * 1000)
  end
end
