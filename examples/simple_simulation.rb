#!/usr/bin/env ruby
# frozen_string_literal: true

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'mutation'

# Configure the simulation
Mutation.configure do |config|
  config.world_size = 15
  config.initial_energy = 12
  config.simulation_delay = 0.1
  config.log_level = :info
end

puts '🧬 Mutation Simulator Example'
puts '=' * 40

# Create a simulator
simulator = Mutation::Simulator.new

# Run for 50 ticks
puts 'Running simulation for 50 ticks...'
simulator.run_for_ticks(50)

# Show final report
puts "\n📊 Final Report:"
puts simulator.detailed_report
