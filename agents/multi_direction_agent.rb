#!/usr/bin/env ruby
# Agent that moves in different directions randomly

require 'json'

begin
  while input = $stdin.gets
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    if message['command'] == 'die'
      exit(0)
    end
    
    # Get world state info
    neighbors = message['neighbors'] || {}
    my_energy = message['energy'] || 0
    
    # Choose a random direction to move
    directions = ['north', 'south', 'east', 'west', 'north_east', 'north_west', 'south_east', 'south_west']
    
    # Find empty neighbors (no living agents)
    empty_directions = []
    directions.each do |dir|
      neighbor = neighbors[dir]
      if neighbor.nil? || neighbor['energy'] == 0 || neighbor['alive'] == false
        empty_directions << dir
      end
    end
    
    # Choose action based on energy and neighbors
    if my_energy <= 2
      # Low energy - rest
      action = { action: 'rest' }
    elsif !empty_directions.empty? && rand < 0.7
      # 70% chance to move if empty spaces available
      direction = empty_directions.sample
      action = { action: 'move', target: direction }
    elsif my_energy >= 8 && rand < 0.3
      # 30% chance to replicate if high energy
      action = { action: 'replicate' }
    else
      # Default to rest
      action = { action: 'rest' }
    end
    
    response = action.merge(memory: {})
    puts JSON.generate(response)
    $stdout.flush
  end
rescue => e
  # Fallback to rest if anything goes wrong
  error_response = { 
    action: 'rest', 
    message: "Error: #{e.message}",
    memory: {}
  }
  puts JSON.generate(error_response)
  $stdout.flush
end