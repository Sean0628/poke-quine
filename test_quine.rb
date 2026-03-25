#!/usr/bin/env ruby
require 'fileutils'
require 'rbconfig'
require 'tmpdir'

QUINE_PATH = File.expand_path('quine.rb', __dir__)
RUBY_BIN = RbConfig.ruby
ART_DIR = File.expand_path('AA', __dir__)

def cycle_steps
  steps = Dir.children(ART_DIR).grep(/\A\d{4}\.txt\z/).count
  return steps unless steps.zero?

  $stderr.puts "No art files found in #{ART_DIR}"
  exit 1
end

def run_quine(input_path, output_path)
  success = system(RUBY_BIN, input_path, out: output_path, err: File::NULL)
  return if success

  $stderr.puts "Failed to execute #{input_path}"
  exit 1
end

Dir.mktmpdir('poke-quine') do |dir|
  steps = cycle_steps
  current_path = File.join(dir, 'q1.rb')
  FileUtils.cp(QUINE_PATH, current_path)

  steps.times do |step|
    next_path = File.join(dir, "q#{step + 2}.rb")
    run_quine(current_path, next_path)
    current_path = next_path
  end

  if File.read(QUINE_PATH) == File.read(current_path)
    $stderr.puts "Cycle verification: PASS (#{steps} steps)"
  else
    $stderr.puts "Cycle verification: FAIL (#{steps} steps)"
    exit 1
  end
end
