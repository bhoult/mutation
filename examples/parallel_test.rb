#!/usr/bin/env ruby
# frozen_string_literal: true

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'mutation'

puts '🧬 Parallel Processing Test'
puts '=' * 50

# Get processor count
require 'parallel'
total_processors = Parallel.processor_count
puts "Available processors: #{total_processors}"

# Configure for parallel processing
Mutation.configure do |config|
  config.world_size = 200 # Much larger world for better parallel benefit
  config.initial_energy = 15
  config.simulation_delay = 0.0 # No delay for performance test
  config.log_level = :warn # Reduce logging for cleaner output
  config.parallel_agents = true
  config.processor_count = total_processors
end

puts "Testing with #{Mutation.configuration.world_size} agents"
puts "Parallel processing: #{Mutation.configuration.parallel_agents}"
puts "Processor count: #{Mutation.configuration.processor_count}"

# Test parallel processing
puts "\nTesting parallel processing..."
start_time = Time.now
simulator = Mutation::Simulator.new
simulator.run_for_ticks(100)
parallel_time = Time.now - start_time

puts "Parallel processing time: #{parallel_time.round(3)} seconds"

# Test sequential processing
puts "\nTesting sequential processing..."
Mutation.configure do |config|
  config.parallel_agents = false
end

start_time = Time.now
simulator = Mutation::Simulator.new
simulator.run_for_ticks(100)
sequential_time = Time.now - start_time

puts "Sequential processing time: #{sequential_time.round(3)} seconds"

# Calculate speedup
speedup = sequential_time / parallel_time
puts "\nResults:"
puts "- Sequential: #{sequential_time.round(3)}s"
puts "- Parallel:   #{parallel_time.round(3)}s"
puts "- Speedup:    #{speedup.round(2)}x"
puts "- Efficiency: #{((speedup / total_processors) * 100).round(1)}%"

puts "\n📊 Performance Summary:"
puts "Using #{total_processors} processors achieved #{speedup.round(2)}x speedup"
